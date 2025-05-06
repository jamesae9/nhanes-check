# nhanes_logic.py
# Core NHANES checking logic ported from nhanesLogic.js
import re
from js import console
from datetime import datetime

def check_for_nhanes(text):
    """Look for mentions of NHANES or National Health and Nutrition Examination Survey"""
    nhanes_regex = r'\bNHANES\b|\bNational Health and Nutrition Examination Survey\b'
    return bool(re.search(nhanes_regex, text, re.IGNORECASE))

def check_nhanes_citation(text):
    """Look for proper citation mentions"""
    citation_patterns = [
        r'Centers for Disease Control and Prevention \(CDC\)',
        r'National Center for Health Statistics \(NCHS\)',
        r'https?:\/\/www\.cdc\.gov\/nchs\/nhanes',
        r'NHANES protocol was approved by the NCHS Research Ethics Review Board',
        r'NHANES data are publicly available'
    ]
    
    found_patterns = []
    
    for pattern in citation_patterns:
        if re.search(pattern, text, re.IGNORECASE):
            found_patterns.append(pattern.replace('\\', ''))
    
    # Check for methods/methodology section
    has_methods_section = bool(re.search(r'\b(?:methods?|methodology)\b', text, re.IGNORECASE))
    
    if len(found_patterns) >= 2 and has_methods_section:
        return {
            'passed': True,
            'details': f'NHANES properly cited. Found {len(found_patterns)} citation elements and methods section.'
        }
    else:
        issues = []
        if len(found_patterns) < 2:
            issues.append(f'Missing proper NHANES citation elements (found only {len(found_patterns)}, need at least 2)')
        if not has_methods_section:
            issues.append("No apparent methods section found")
        
        return {
            'passed': False,
            'details': f'NHANES citation issues: {"; ".join(issues)}'
        }

def check_survey_design_acknowledgment(text):
    """Check for survey design acknowledgment (temporarily disabled)"""
    return {
        'passed': True,  # Keeps it from being treated as a critical failure for now
        'skipped': True,  # Add the skipped flag
        'details': "Check for Survey Design Acknowledgment is currently disabled."
    }

def check_weighting_methodology(text):
    """Check for weighting methodology (temporarily disabled)"""
    return {
        'passed': True,  # Keeps it from being treated as a critical failure for now
        'skipped': True,  # Add the skipped flag
        'details': "Check for Weighting Methodology is currently disabled."
    }

def check_nhanes_date_range(text):
    """
    Checks text for year ranges potentially related to NHANES or similar datasets.
    Validates ranges based on:
    1. Plausibility (within reasonable year boundaries: MIN_PLAUSIBLE_YEAR to currentYear).
    2. Start year is odd, end year is even.
    """
    # Configuration for plausibility
    MIN_PLAUSIBLE_YEAR = 1950
    current_year = datetime.now().year
    MAX_PLAUSIBLE_YEAR = current_year

    # Regex to find potential year ranges, possibly associated with NHANES
    cycle_regex = r'(?:NHANES|National Health and Nutrition Examination Survey)?\s*(?:data)?\s*(?:from)?\s*(?:the)?\s*(?:years?)?\s*(?:(?:19|20)\d{2})(?:\s*[-–—]\s*(?:(?:19|20)\d{2}))?|(?:(?:19|20)\d{2})(?:\s*[-–—]\s*(?:(?:19|20)\d{2}))?\s*(?:NHANES|National Health and Nutrition Examination Survey)'
    
    matches = re.findall(cycle_regex, text, re.IGNORECASE) or []
    found_valid_range = False
    found_invalid_range = False
    found_implausible_range = False
    valid_range_details = []
    invalid_range_details = []
    implausible_range_details = []
    
    if not matches:
        # Broader search for *any* YYYY-YYYY pattern if specific NHANES context is missed
        generic_range_regex = r'(?:19|20)\d{2}\s*[-–—]\s*(?:19|20)\d{2}'
        matches = re.findall(generic_range_regex, text) or []
    
    # If still no matches, we can't perform the check effectively
    if not matches:
        return {
            'passed': True,  # Pass leniently if no range is mentioned
            'details': "No potential year ranges found to validate."
        }
    
    year_regex = r'(?:19|20)\d{2}'
    
    for match_text in matches:
        years = [int(year) for year in re.findall(year_regex, match_text)]
        
        # We are only interested in pairs of years (start-end)
        if len(years) == 2:
            start_year, end_year = years
            
            # Plausibility Checks
            is_plausible = (
                start_year >= MIN_PLAUSIBLE_YEAR and
                end_year <= MAX_PLAUSIBLE_YEAR and
                end_year >= start_year
            )
            
            if not is_plausible:
                found_implausible_range = True
                implausible_range_details.append(f"{start_year}-{end_year} (in \"{match_text}\")")
                continue  # Skip validation for this implausible range
            
            # Validation Check (Odd Start, Even End)
            if start_year % 2 == 1 and end_year % 2 == 0:
                # Meets the odd-start, even-end criteria
                found_valid_range = True
                valid_range_details.append(f"{start_year}-{end_year}")
            else:
                # Is a plausible date range but fails the odd/even rule
                found_invalid_range = True
                invalid_range_details.append(f"{start_year}-{end_year} (in \"{match_text}\")")
    
    # Determine final result based on findings
    details = ""
    passed = True  # Default to passing unless an explicit invalid range is found
    
    if found_valid_range:
        passed = True  # At least one valid range found
        details = f"Valid OddStart-EvenEnd date range(s) found: {', '.join(list(set(valid_range_details)))}."
        if found_invalid_range:
            details += f" (Also found plausible ranges failing the OddStart-EvenEnd rule: {', '.join(list(set(invalid_range_details)))})"
    elif found_invalid_range:
        passed = False  # Explicitly invalid ranges found, and no valid ones
        details = f"No valid OddStart-EvenEnd ranges confirmed. Found plausible ranges with issues: {', '.join(list(set(invalid_range_details)))}."
    elif found_implausible_range:
        # Only found ranges that were filtered out as implausible (e.g., page numbers, future dates)
        passed = True  # Lenient pass - no *date* ranges were found to violate the rule
        details = "Found number ranges, but they were filtered out as unlikely calendar year ranges (e.g., potentially page numbers or out of date bounds)."
    else:
        # Matches were found by regex, but didn't yield 2 years, or something unexpected occurred.
        passed = True  # Pass leniently
        details = "Could not definitively identify plausible year ranges for validation from the text patterns found."
    
    return {'passed': passed, 'details': details}

# --- Additional NHANES Checker Functions ---

def extract_manuscript_topics(text):
    """Extract the main health topics from the manuscript based on keyword frequency"""
    # Extract title and abstract
    title_match = re.search(r'^(?:Title\s*[:\s]*)?([^\n]+)', text, re.IGNORECASE)
    abstract_regex = r'\bAbstract\b([\s\S]*?)(?=\n\s*\b(Keywords|Introduction|Background|Methods)\b|\n{2,})'
    abstract_match = re.search(abstract_regex, text, re.IGNORECASE)
    
    title = title_match.group(1).strip() if title_match else ""
    abstract = abstract_match.group(1).strip() if abstract_match else ""
    
    # Focus analysis on title and abstract; fallback to first ~500 words
    analysis_text = (title + " " + abstract).strip() or text[:3000]
    
    if not analysis_text:
        return ["General Health/Unknown"]  # Default if no text
    
    # Domain keywords
    health_domains = {
        "Cardiovascular": ["heart", "cardiac", "cardiovascular", "blood pressure", "hypertension", "cholesterol", "stroke", "atherosclerosis", "vascular", "lipids", "arrhythmia"],
        "Nutrition/Diet": ["diet", "dietary", "food", "nutrition", "nutrient", "intake", "consumption", "supplement", "eating pattern", "malnutrition", "vitamin", "mineral", "fiber", "calories"],
        "Metabolic/Endocrine": ["diabetes", "insulin", "glucose", "metabolic syndrome", "obesity", "BMI", "body mass index", "thyroid", "endocrine", "adiposity", "waist circumference", "hormone"],
        "Epidemiology/Public Health": ["prevalence", "incidence", "risk factor", "population", "demographic", "public health", "mortality", "morbidity", "surveillance", "trends", "disparities", "socioeconomic"],
        "Mental Health/Neurology": ["depression", "anxiety", "psychiatric", "mental", "psychological", "cognitive", "cognition", "neurologic", "stress", "mood", "suicide"],
        "Respiratory": ["lung", "pulmonary", "respiratory", "asthma", "COPD", "breathing", "sleep apnea", "spirometry"],
        "Oncology": ["cancer", "tumor", "oncology", "malignancy", "carcinoma", "neoplasm"],
        "Pediatrics": ["child", "children", "adolescent", "pediatric", "youth", "infant", "growth", "development"],
        "Geriatrics": ["elderly", "older adults", "aging", "geriatric", "seniors", "frailty"],
        "Renal/Urology": ["kidney", "renal", "nephrology", "chronic kidney disease", "CKD", "urinary", "urology"],
        "Musculoskeletal/Physical Activity": ["bone", "muscle", "physical activity", "exercise", "sedentary", "osteoporosis", "arthritis", "sarcopenia", "fitness"],
        "Environmental Health": ["exposure", "pollutant", "environment", "toxin", "heavy metal", "pesticide", "air quality", "lead", "mercury", "cadmium"],
        "Infectious Disease": ["infection", "virus", "bacteria", "antibody", "vaccine", "hepatitis", "HIV"],
        "Gastroenterology": ["gut", "gastrointestinal", "liver", "hepatic", "digestive"],
        "Allergy/Immunology": ["allergy", "asthma", "immune", "inflammation", "antibody"]
    }
    
    domain_scores = {}
    
    for domain, keywords in health_domains.items():
        domain_scores[domain] = 0
        for keyword in keywords:
            # Case-insensitive, whole word match
            regex = r'\b' + re.escape(keyword) + r'\b'
            matches = len(re.findall(regex, analysis_text, re.IGNORECASE) or [])
            if matches > 0:
                domain_scores[domain] += matches
    
    # Filter out domains with zero score and sort
    sorted_domains = sorted(
        [(domain, score) for domain, score in domain_scores.items() if score > 0],
        key=lambda x: x[1],
        reverse=True
    )
    
    # Determine top domains - require a minimum score and take top N
    min_score_threshold = 2  # Require at least 2 mentions to be considered significant
    top_n = 3
    top_domains = [
        domain for domain, score in sorted_domains 
        if score >= min_score_threshold
    ][:top_n]
    
    return top_domains if top_domains else ["General Health/Mixed"]


def check_nhanes_cycle_recency(text):
    """
    Checks text for YYYY-YYYY date ranges that DIRECTLY FOLLOW an NHANES mention
    according to a specific pattern.
    Validates ranges based on:
    1. Plausibility (within reasonable year boundaries: MIN_PLAUSIBLE_YEAR to currentYear).
    2. Start year is odd, end year is even.
    """
    from datetime import datetime
    
    MIN_PLAUSIBLE_YEAR = 1950
    current_year = datetime.now().year
    MAX_PLAUSIBLE_YEAR = current_year
    
    # This regex specifically looks for "NHANES_KEYWORD [optional_words] YYYY-YYYY"
    # The NHANES keyword part is MANDATORY for a match
    nhanes_then_date_range_regex = r'(?:NHANES|National Health and Nutrition Examination Survey)\s*(?:data)?\s*(?:from)?\s*(?:the)?\s*(?:years?)?\s*((?:19|20)\d{2})\s*[-–—]\s*((?:19|20)\d{2})'
    
    # Find matches in text
    matches = re.findall(nhanes_then_date_range_regex, text, re.IGNORECASE)
    
    found_valid_range = False
    found_invalid_range = False
    found_implausible_range = False
    valid_range_details = []
    invalid_range_details = []
    implausible_range_details = []
    
    if not matches:
        return {
            'passed': True,  # Pass leniently if no "NHANES... YYYY-YYYY" pattern is found
            'details': "No date ranges found directly following an NHANES mention with the expected pattern."
        }
    
    # Find full context matches to show in details
    full_matches = re.findall(r'(?:NHANES|National Health and Nutrition Examination Survey)\s*(?:data)?\s*(?:from)?\s*(?:the)?\s*(?:years?)?\s*(?:19|20)\d{2}\s*[-–—]\s*(?:19|20)\d{2}', text, re.IGNORECASE)
    
    for i, year_pair in enumerate(matches):
        if len(year_pair) == 2:
            start_year = int(year_pair[0])
            end_year = int(year_pair[1])
            
            match_text = full_matches[i] if i < len(full_matches) else f"NHANES {start_year}-{end_year}"
            
            is_plausible = (
                start_year >= MIN_PLAUSIBLE_YEAR and
                end_year <= MAX_PLAUSIBLE_YEAR and
                end_year >= start_year
            )
            
            if not is_plausible:
                found_implausible_range = True
                implausible_range_details.append(f"{start_year}-{end_year} (in \"{match_text}\")")
                continue
            
            if start_year % 2 == 1 and end_year % 2 == 0:
                found_valid_range = True
                valid_range_details.append(f"{start_year}-{end_year}")
            else:
                found_invalid_range = True
                invalid_range_details.append(f"{start_year}-{end_year} (in \"{match_text}\")")
    
    # Determine final result based on findings
    details = ""
    passed = True
    
    if found_valid_range:
        passed = True
        details = f"Valid OddStart-EvenEnd date range(s) following an NHANES mention found: {', '.join(list(set(valid_range_details)))}."
        if found_invalid_range:
            details += f" (Also found plausible ranges following NHANES mentions that failed the OddStart-EvenEnd rule: {', '.join(list(set(invalid_range_details)))})"
    elif found_invalid_range:
        passed = False
        details = f"No valid OddStart-EvenEnd ranges confirmed following NHANES mentions. Found plausible ranges with issues: {', '.join(list(set(invalid_range_details)))}."
    elif found_implausible_range:
        passed = True  # Lenient pass if only implausible ones were found matching the pattern
        details = "Found date ranges following NHANES mentions, but they were filtered out as implausible (e.g., out of date bounds)."
    else:
        passed = True  # Pass leniently
        details = "Could not definitively validate year ranges from the 'NHANES...YYYY-YYYY' patterns found."
    
    return {'passed': passed, 'details': details}


def check_title_template(text):
    """Check if the title appears to use a templated structure"""
    # Extract the title
    title_regex = r'^(?:Title\s*[:\s]*)?([^\n]+)'
    title_match = re.search(title_regex, text, re.IGNORECASE)
    
    if not title_match or not title_match.group(1):
        return {
            'passed': True,  # Pass if title can't be found reliably
            'details': "Could not reliably extract a title to check for templating."
        }
    
    title = title_match.group(1).strip()
    
    # Patterns indicative of common templates
    association_pattern = r'\b(association|relationship|correlation|link|association|impact|effect|influence|predictor)\b.*?\b(between|among|of|on|with)\b'
    population_pattern = r'\b(among|in|across|within)\b.*?\b(U\.S\.|US|American|population|adults|children|adolescents|participants|individuals|subjects|men|women|patient)\b'
    study_design_pattern = r'\b(cross-sectional|longitudinal|cohort|survey|analysis|study)\b'
    nhanes_pattern = r'\b(NHANES|National Health and Nutrition Examination Survey)'
    
    # Score based on presence of these elements
    score = 0
    if re.search(association_pattern, title, re.IGNORECASE):
        score += 1
    if re.search(population_pattern, title, re.IGNORECASE):
        score += 1
    if re.search(study_design_pattern, title, re.IGNORECASE) or re.search(nhanes_pattern, title, re.IGNORECASE):
        score += 1
    
    # Check for generic phrases often found in templates
    common_phrases = bool(re.search(r'\b(data from the|using data from|analysis of|based on the)\b', title, re.IGNORECASE))
    
    # Check for keyword stuffing (arbitrary threshold for too many keywords)
    words = [w for w in re.split(r'[\s,:-]+', title.lower()) if len(w) > 2]
    keyword_stuffing = len(words) > 15
    
    # Define failure conditions
    if score >= 2 and common_phrases:
        return {
            'passed': False,
            'details': f'Title "{title}" appears potentially templated (Score: {score}, Common Phrase: Yes). Contains common association/population/study elements.'
        }
    
    if score >= 3:
        return {
            'passed': False,
            'details': f'Title "{title}" appears strongly templated (Score: {score}). Matches multiple common patterns.'
        }
    
    if keyword_stuffing:
        return {
            'passed': False,
            'details': f'Title "{title}" might be overly long or keyword-stuffed.'
        }
    
    return {
        'passed': True,
        'details': f'Title does not appear excessively templated (Score: {score}, Common Phrase: {"Yes" if common_phrases else "No"}).'
    }


def check_author_red_flags(text):
    """Check for red flags in author information including non-institutional emails, mismatched affiliations, etc."""
    # Get topics using the extracted function
    topics = extract_manuscript_topics(text)
    
    # Find author/affiliation section
    author_section_regex = r'(?:\bAbstract\b[\s\S]*?)(?:\n\s*(?:Authors?|Affiliations?)\b\s*[:\n]?)([\s\S]*?)(?=\n\s*\b(Introduction|Background|Methods|Results|Discussion|Conclusion|References|Acknowledgments)\b|\n{3,})'
    author_section_match = re.search(author_section_regex, text, re.IGNORECASE)
    author_section = author_section_match.group(1).strip() if author_section_match else ""
    
    # Fallback: If no clear section, look broadly for emails and affiliations near the start
    if not author_section:
        first_part_of_text = text[:3000]
        email_regex_global = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'
        affiliation_regex_global = r'\b(?:Department|Dept|Division|School|Faculty|Center|Institute|Hospital|University|College)\b'
        
        if (re.search(email_regex_global, first_part_of_text, re.IGNORECASE) or 
            re.search(affiliation_regex_global, first_part_of_text, re.IGNORECASE)):
            # Consider the first ~1000 characters as potential author info section
            author_section = first_part_of_text[:1000]
        else:
            return {
                'passed': True,  # Cannot perform check if no author info found
                'details': "Could not reliably extract author/affiliation information."
            }
    
    # --- Flag 1: Non-Institutional Emails ---
    email_regex = r'\b[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})\b'
    emails = re.findall(email_regex, author_section)
    non_institutional_domains = [
        'gmail\.com', 'yahoo\.com', 'hotmail\.com', 'outlook\.com', 
        'aol\.com', 'icloud\.com', 'protonmail\.com', 'qq\.com', 
        '163\.com', 'mail\.com', 'yandex\.com'
    ]
    non_inst_pattern = '|'.join(non_institutional_domains)
    non_institutional_emails = [email for email in emails if re.search(non_inst_pattern, email, re.IGNORECASE)]
    
    # Flag if > 50% are non-institutional AND there's at least one such email
    has_non_institutional_emails = False
    email_flag_details = ''
    if emails:
        has_non_institutional_emails = (len(non_institutional_emails) / len(emails) > 0.5)
        if has_non_institutional_emails:
            email_flag_details = f'Majority ({len(non_institutional_emails)}/{len(emails)}) non-institutional emails; '
    
    # --- Flag 2: Mismatched Departments/Affiliations ---
    affiliation_regex = r'\b(?:Department|Dept|Division|School|Faculty|Center|Institute|Hospital|University|College|Laboratory|Program|Unit|Clinic)\s+(?:of\s+)?([A-Za-z\s,&\'-]+)'
    affiliation_matches = re.findall(affiliation_regex, author_section, re.IGNORECASE)
    affiliations = [re.sub(r'[\d,.;]+$', '', match).strip().lower() for match in affiliation_matches]
    
    # Relevance mapping for affiliations
    relevance_mappings = {
        "Cardiovascular": ["cardiology", "cardiovascular", "vascular", "heart", "preventive medicine", "internal medicine"],
        "Nutrition/Diet": ["nutrition", "dietetics", "food science", "public health", "preventive medicine", "metabolism"],
        "Metabolic/Endocrine": ["endocrinology", "metabolic", "diabetes", "obesity", "medicine", "internal medicine"],
        "Epidemiology/Public Health": ["epidemiology", "public health", "biostatistics", "community health", "preventive medicine", "statistics", "population health"],
        "Mental Health/Neurology": ["psychiatry", "psychology", "neurology", "behavioral", "neuroscience", "mental health"],
        "General Health/Mixed": ["medicine", "health science", "public health", "biology", "biostatistics", "statistics", "internal medicine", "family medicine", "nursing", "pharmacy"]
    }
    
    relevant_affiliations_count = 0
    unique_affiliations = list(set([affil for affil in affiliations if len(affil) > 2]))
    
    for affil in unique_affiliations:
        is_relevant = False
        # Check against identified topics
        for topic in topics:
            relevant_terms = relevance_mappings.get(topic, relevance_mappings["General Health/Mixed"])
            if any(term in affil for term in relevant_terms):
                is_relevant = True
                break
        
        # Check against general health terms if not already relevant
        if not is_relevant:
            general_terms = relevance_mappings["General Health/Mixed"]
            if any(term in affil for term in general_terms):
                is_relevant = True
        
        if is_relevant:
            relevant_affiliations_count += 1
    
    # Flag if < 50% affiliations seem relevant AND there are affiliations listed
    has_mismatched_affiliations = False
    mismatch_flag_details = ''
    if unique_affiliations:
        has_mismatched_affiliations = (relevant_affiliations_count / len(unique_affiliations)) < 0.5
        if has_mismatched_affiliations:
            mismatch_flag_details = f'Affiliations ({relevant_affiliations_count}/{len(unique_affiliations)} relevant) may not align well with topics ({", ".join(topics)}); '
    
    # --- Flag 3: Claims of Data Collection ---
    collection_context_regex = r'\b(?:we|authors?)\s+(?:collected|gathered|obtained|acquired|assembled|recruited)\s+(?:(?:the|these|our)\s+)?(?:participants|subjects|(?:NHANES\s+)?data)\b'
    claims_data_collection = bool(re.search(collection_context_regex, text, re.IGNORECASE))
    collection_flag_details = 'Potentially claims to have collected the NHANES data/participants; ' if claims_data_collection else ''
    
    # --- Combine Flags ---
    red_flags_found = [flag for flag in [has_non_institutional_emails, has_mismatched_affiliations, claims_data_collection] if flag]
    red_flag_count = len(red_flags_found)
    
    if red_flag_count >= 1:  # Fail on 1 or more strong flags
        details = f'Found {red_flag_count} potential author/affiliation red flag(s): {email_flag_details}{mismatch_flag_details}{collection_flag_details}'
        return {
            'passed': False,
            'details': details.strip()
        }
    
    return {
        'passed': True,
        'details': f'Author information appears plausible ({red_flag_count} red flags detected). Topics: {", ".join(topics)}.'
    }

# Main function that orchestrates all checks
def check_nhanes_manuscript(text, title='Untitled Manuscript'):
    """Main orchestration function"""
    console.log(f'Checking manuscript: {title}')
    
    # Check 1: Does it mention NHANES?
    has_nhanes = check_for_nhanes(text)
    
    if not has_nhanes:
        return {
            'isNHANES': False,
            'finalResult': "Not NHANES",
            'details': ["The manuscript does not appear to use NHANES data."],
            'checkResults': []
        }
    
    results = {
        'isNHANES': True,
        'checkResults': [],
        'details': ["✓ STEP 1: Manuscript mentions NHANES."],
        'finalResult': "",
        'failStep': 0  # Track which step caused failure
    }
    
    # Define checks in order
    checks = [
    {"name": "2a. NHANES Citation", "func": check_nhanes_citation, "step": 2, "critical": True},
    {"name": "2b. Survey Design Acknowledgment", "func": check_survey_design_acknowledgment, "step": 2, "critical": True},
    {"name": "2c. Weighting Methodology", "func": check_weighting_methodology, "step": 2, "critical": True},
    {"name": "3. NHANES Date Range", "func": check_nhanes_date_range, "step": 3, "critical": False},
    {"name": "4. NHANES Cycle Recency", "func": check_nhanes_cycle_recency, "step": 4, "critical": False},
    {"name": "5. Title Template Check", "func": check_title_template, "step": 5, "critical": False},
    {"name": "6. Author Red Flags", "func": check_author_red_flags, "step": 6, "critical": False}
    ]
    
    current_step = 1
    methodology_passed = True  # Specifically track step 2 passes
    
    for check in checks:
        # Update step summary if moving to a new step number
        if check["step"] > current_step:
            # Check if Step 2 (Methodology) failed overall before moving on
            if current_step == 2 and not methodology_passed:
                results['finalResult'] = "Fail"
                results['failStep'] = 2
                results['details'].append("✗ STEP 2: Failed one or more critical methodology checks.")
                break  # Stop processing critical methodology failure
            
            # Log success of the previous step block (if not already failed)
            if results['finalResult'] != "Fail":
                results['details'].append(f"✓ STEP {current_step}: Check(s) passed.")
            
            current_step = check["step"]  # Move to the new step number
        
        # Execute the check function
        check_result = check["func"](text)
        results['checkResults'].append({
            'checkName': check["name"],
            'passed': check_result.get('passed', False),
            'details': check_result.get('details', ''),
            'skipped': check_result.get('skipped', False)
        })
        
        # Handle failed check (only if not skipped)
        if not check_result.get('passed', False) and not check_result.get('skipped', False):
            if check["step"] == 2:
                methodology_passed = False
            
            if check["critical"]:
                results['finalResult'] = "Fail"
                results['failStep'] = check["step"]
                if not any(d.startswith('✗ STEP') for d in results['details']):
                    results['details'].append(f"✗ STEP {check['step']}: Failed critical check \"{check['name']}\".")
                
                if check["step"] > 2:
                    break
            else:
                results['details'].append(f"⚠️ STEP {check['step']}: Non-critical issue found in check \"{check['name']}\".")
    
    # Set final results
    if results['finalResult'] != "Fail":
        results['details'].append(f"✓ STEP {current_step}: Check(s) passed.")
        results['finalResult'] = "Pass"
        results['details'].append("✓ ALL CRITICAL CHECKS PASSED.")
    else:
        if results['failStep'] == 0 and results['isNHANES']:
            results['failStep'] = current_step
        
        results['details'].append(f"✗ Manuscript check failed at Step {results['failStep']}.")
    
    return results