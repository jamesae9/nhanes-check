# main.py
# Main module for initialization and event handlers

import js
from js import document, console, window
from pyodide.ffi import create_proxy

# Import other modules
import nhanes_logic
import file_utils
import ui

async def handle_file_upload(event):
    """Handle file upload event"""
    file = event.target.files[0]
    if not file:
        return
    
    # Clear results
    document.getElementById('results').classList.add('hidden')
    document.getElementById('resultsContent').innerHTML = ''
    
    # Show loading
    window.NHANESBridge.showUILoading(f"Loading file: {file.name}...")
    
    try:
        # Process file based on extension
        file_extension = file.name.split('.')[-1].lower()
        
        if file_extension == 'txt':
            content = await file_utils.read_text_file(file)
        elif file_extension == 'docx':
            content = await file_utils.read_docx_file(file)
        elif file_extension == 'pdf':
            # Create progress callback
            def update_progress(current, total):
                window.NHANESBridge.showUILoading(f"Loading PDF: {file.name} ({current}/{total} pages)...")
            
            progress_proxy = create_proxy(update_progress)
            content = await file_utils.read_pdf_file(file, progress_proxy)
        else:
            error_msg = f"Unsupported file type: .{file_extension}. Please upload a .txt, .docx, or .pdf file."
            document.getElementById('manuscriptText').value = error_msg
            js.alert(error_msg)
            window.NHANESBridge.hideUILoading(False)
            return
            
        # Update textarea with content
        document.getElementById('manuscriptText').value = content
        window.NHANESBridge.hideUILoading(True)
        
    except Exception as e:
        error_msg = f"Error processing file: {str(e)}"
        document.getElementById('manuscriptText').value = error_msg
        js.alert(error_msg)
        window.NHANESBridge.hideUILoading(False)

def handle_check_button(event):
    """Handle check button click"""
    manuscript_text = document.getElementById('manuscriptText').value
    
    if not manuscript_text.strip() or manuscript_text.startswith("Loading") or manuscript_text.startswith("Error") or manuscript_text.startswith("Unsupported"):
        js.alert('Please wait for loading to complete or upload a valid file content.')
        return
        
    document.getElementById('results').classList.add('hidden')
    window.NHANESBridge.showUILoading("Running NHANES checks...")
    
    try:
        # Run the checks
        results = nhanes_logic.check_nhanes_manuscript(manuscript_text, "Manuscript")
        ui.display_results(results)
    except Exception as e:
        console.error("Error during manuscript check:", e)
        # Display error results
        error_results = {
            'finalResult': "Error",
            'details': [f"An unexpected error occurred during analysis: {str(e)}"],
            'checkResults': []
        }
        ui.display_results(error_results)
    finally:
        window.NHANESBridge.hideUILoading(True)
        # Scroll to results if needed
        if document.getElementById('resultsContent').innerHTML.trim() != '':
            document.getElementById('results').scrollIntoView({'behavior': 'smooth', 'block': 'start'})

def handle_clear_button(event):
    """Handle clear button click"""
    document.getElementById('manuscriptText').value = ''
    document.getElementById('manuscriptFile').value = ''
    document.getElementById('results').classList.add('hidden')
    document.getElementById('resultsContent').innerHTML = ''
    document.getElementById('checkButton').disabled = True

def initialize():
    """Initialize the application"""
    console.log("Initializing NHANES Checker (Python version)")
    
    # Hide the loading message and show the app
    document.getElementById('pyodideLoading').classList.add('hidden')
    document.getElementById('appContent').classList.remove('hidden')
    
    # Set up event listeners
    check_button = document.getElementById('checkButton')
    if check_button:
        check_button.addEventListener('click', create_proxy(handle_check_button))
    
    file_input = document.getElementById('manuscriptFile')
    if file_input:
        file_input.addEventListener('change', create_proxy(handle_file_upload))
    
    clear_button = document.getElementById('clearButton')
    if clear_button:
        clear_button.addEventListener('click', create_proxy(handle_clear_button))
    
    # Set up textarea input change detection
    textarea = document.getElementById('manuscriptText')
    if textarea:
        def enable_check_if_text(event):
            check_button.disabled = not bool(textarea.value.strip())
        textarea.addEventListener('input', create_proxy(enable_check_if_text))
    
    # Initial UI state
    window.NHANESBridge.hideUILoading(False)
    console.log("NHANES Checker initialized and ready")