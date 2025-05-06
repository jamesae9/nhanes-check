// File handling bridge between JavaScript and Python
window.NHANESBridge = {
  async fetchTextFromFile(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => resolve(e.target.result);
      reader.onerror = (e) => reject(new Error(`Error reading file: ${e.target.error}`));
      reader.readAsText(file);
    });
  },

  async fetchArrayBufferFromFile(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => resolve(e.target.result);
      reader.onerror = (e) => reject(new Error(`Error reading file: ${e.target.error}`));
      reader.readAsArrayBuffer(file);
    });
  },

  showUILoading(message = "Processing...") {
    const textarea = document.getElementById('manuscriptText');
    const checkButton = document.getElementById('checkButton');
    const clearButton = document.getElementById('clearButton');
    const fileInput = document.getElementById('manuscriptFile');
    
    if (textarea) textarea.value = message;
    if (textarea) textarea.disabled = true;
    if (checkButton) checkButton.disabled = true;
    if (clearButton) clearButton.disabled = true;
    if (fileInput) fileInput.disabled = true;
  },

  hideUILoading(enableCheckButton = true) {
    const textarea = document.getElementById('manuscriptText');
    const checkButton = document.getElementById('checkButton');
    const clearButton = document.getElementById('clearButton');
    const fileInput = document.getElementById('manuscriptFile');
    
    if (textarea) textarea.disabled = false;
    if (checkButton) checkButton.disabled = !enableCheckButton;
    if (clearButton) clearButton.disabled = false;
    if (fileInput) fileInput.disabled = false;
  }
};