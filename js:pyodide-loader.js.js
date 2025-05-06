// Loads Pyodide and Python modules
(async function() {
  try {
    console.log("Loading Pyodide...");
    const pyodide = await loadPyodide();
    window.pyodide = pyodide;
    
    // Import base packages
    await pyodide.loadPackagesFromImports('import re');
    
    // Create virtual file system directories
    pyodide.runPython(`
      import os
      os.makedirs('/python', exist_ok=True)
    `);
    
    // Load Python files into virtual filesystem
    const pythonFiles = [
      {path: '/python/nhanes_logic.py', url: 'python/nhanes_logic.py'},
      {path: '/python/file_utils.py', url: 'python/file_utils.py'},
      {path: '/python/ui.py', url: 'python/ui.py'},
      {path: '/python/main.py', url: 'python/main.py'}
    ];
    
    // Load all Python files
    for (const file of pythonFiles) {
      console.log(`Loading ${file.url}...`);
      const response = await fetch(file.url);
      const content = await response.text();
      
      // Write to virtual filesystem
      pyodide.FS.writeFile(file.path, content);
    }
    
    // Initialize Python path to include our modules
    pyodide.runPython(`
      import sys
      if '/python' not in sys.path:
          sys.path.append('/python')
    `);
    
    // Run the main module
    console.log("Starting NHANES Checker...");
    await pyodide.runPythonAsync(`
      import main
      main.initialize()
    `);
    
  } catch (error) {
    console.error("Error initializing Pyodide:", error);
    document.getElementById('pyodideLoading').innerHTML = 
      '<div style="color: #dc3545; font-weight: bold;">Error loading Python environment: ' + 
      error.message + '</div><div>Please refresh the page to try again.</div>';
  }
})();