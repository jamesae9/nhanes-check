# ui.py
# UI functions for NHANES Checker

from js import document, console

def display_results(results):
    """
    Display check results in the UI
    
    Args:
        results: Dictionary containing check results and details
    """
    # Get references to HTML elements
    results_el = document.getElementById('results')
    results_content = document.getElementById('resultsContent')
    
    # Ensure elements exist
    if not results_el or not results_content:
        console.error("UI Error: Results container elements not found in the DOM.")
        return
    
    # Make results section visible
    results_el.classList.remove('hidden')
    
    # Clear any previous results
    results_content.innerHTML = ''
    
    # --- Overall Result Banner ---
    overall_result_div = document.createElement('div')
    overall_class = 'check-item'  # Base class
    result_text = f"Overall Result: {results['finalResult']}"
    
    # Apply specific class based on the final result
    if results['finalResult'] == 'Pass':
        overall_class += ' pass'
    elif results['finalResult'] == 'Fail':
        overall_class += ' fail'
        # Add step failure detail if available
        if results.get('failStep', 0) > 0:
            result_text += f" (Failed at Step {results['failStep']})"
    elif results['finalResult'] == 'Not NHANES':
        overall_class += ' not-nhanes'
    elif results['finalResult'] == 'Error':
        overall_class += ' fail'  # Style errors as failures
        result_text = 'Processing Error'
    else:
        overall_class += ' not-nhanes'
        result_text = f"Result: {results['finalResult'] or 'Unknown'}"
    
    overall_result_div.className = overall_class
    overall_result_div.innerHTML = f'<div class="summary">{result_text}</div>'
    results_content.appendChild(overall_result_div)
    
    # --- Summary Details Section ---
    if results.get('details') and isinstance(results['details'], list) and results['details']:
        summary_details_div = document.createElement('div')
        summary_details_div.className = 'summary-details'
        summary_details_div.innerHTML = '<h3>Processing Details:</h3>'
        
        summary_list = document.createElement('ul')
        
        for detail in results['details']:
            item = document.createElement('li')
            item.textContent = detail
            
            # Apply inline styles based on prefixes
            if detail.startswith('✗'):
                item.style.color = '#dc3545'  # Fail color
                item.style.fontWeight = 'bold'
            elif detail.startswith('✓'):
                item.style.color = '#28a745'  # Pass color
            elif detail.startswith('⚠️'):
                item.style.color = '#ffc107'  # Warning color
                item.style.fontWeight = 'bold'
            
            summary_list.appendChild(item)
        
        summary_details_div.appendChild(summary_list)
        results_content.appendChild(summary_details_div)
    
    # --- Individual Check Results Section (Collapsible) ---
    if results.get('checkResults') and isinstance(results['checkResults'], list) and results['checkResults']:
        checks_section = document.createElement('details')
        checks_section.className = 'individual-checks'
        
        summary_toggle = document.createElement('summary')
        summary_toggle.innerHTML = '<h3>Individual Check Details ▼</h3>'
        checks_section.appendChild(summary_toggle)
        
        # Add details for each check result
        for check in results['checkResults']:
            check_item = document.createElement('div')
            status_text = ''
            item_class = 'check-item'  # Base class for styling
            
            if check.get('skipped', False):
                item_class += ' skipped'
                status_text = '<span style="color:#6c757d; font-weight:bold;">⚪ Skipped</span>'
            elif check.get('passed', False):
                item_class += ' pass'
                status_text = '<span style="color:#28a745; font-weight:bold;">✓ Pass</span>'
            else:
                item_class += ' fail'
                status_text = '<span style="color:#dc3545; font-weight:bold;">✗ Fail</span>'
            
            check_item.className = item_class
            
            # Populate the check item's content
            check_item.innerHTML = f"""
                <h4>{check.get('checkName', 'Unknown Check')}: {status_text}</h4>
                <p>{check.get('details', 'No details provided.')}</p>
            """
            
            checks_section.appendChild(check_item)
        
        results_content.appendChild(checks_section)