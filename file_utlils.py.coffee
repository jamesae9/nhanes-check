# file_utils.py
# File processing utilities for NHANES Checker

from js import window, mammoth, pdfjsLib, console
from pyodide.ffi import create_proxy

async def read_text_file(file):
    """
    Read a text file
    
    Args:
        file: JavaScript File object
        
    Returns:
        str: The text content of the file
    """
    try:
        content = await window.NHANESBridge.fetchTextFromFile(file)
        return content
    except Exception as e:
        console.error("Error reading text file:", e)
        raise Exception(f"Error reading text file: {str(e)}")

async def read_docx_file(file):
    """
    Read a Microsoft Word (DOCX) file using mammoth.js
    
    Args:
        file: JavaScript File object
        
    Returns:
        str: The extracted text content from the DOCX file
    """
    try:
        array_buffer = await window.NHANESBridge.fetchArrayBufferFromFile(file)
        result = await mammoth.extractRawText({'arrayBuffer': array_buffer})
        return result.value
    except Exception as e:
        console.error("Error processing DOCX file:", e)
        raise Exception(f"Error processing DOCX file: {str(e)}")

async def read_pdf_file(file, progress_callback=None):
    """
    Read a PDF file using PDF.js
    
    Args:
        file: JavaScript File object
        progress_callback: Optional callback function to report loading progress
        
    Returns:
        str: The extracted text content from the PDF file
    """
    try:
        # Read file as array buffer
        array_buffer = await window.NHANESBridge.fetchArrayBufferFromFile(file)
        
        # Set PDF.js worker
        pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.16.105/pdf.worker.min.js'
        
        # Load PDF document
        loading_task = pdfjsLib.getDocument({'data': array_buffer})
        pdf = await loading_task.promise
        
        # Initialize progress tracking
        total_pages = pdf.numPages
        pages_processed = 0
        
        if progress_callback:
            progress_callback(pages_processed, total_pages)
        
        # Extract text from all pages
        page_texts = []
        
        for i in range(1, total_pages + 1):
            # Get page
            page = await pdf.getPage(i)
            
            # Extract text content
            text_content = await page.getTextContent()
            
            # Join text items
            page_text = ' '.join([item.str for item in text_content.items])
            page_texts.append(page_text)
            
            # Update progress
            pages_processed += 1
            if progress_callback:
                progress_callback(pages_processed, total_pages)
        
        # Join all pages with double newlines
        full_text = '\n\n'.join(page_texts)
        return full_text
    except Exception as e:
        console.error("Error processing PDF file:", e)
        raise Exception(f"Error processing PDF file: {str(e)}")