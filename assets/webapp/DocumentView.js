document.querySelectorAll('img').forEach((img) => {
    img.addEventListener('click', () => {
      window.flutter_inappwebview.callHandler('onImageClick', img.src);
    });
  });

  document.querySelectorAll('input, textarea').forEach((input) => {
      const eventType = input.type === 'checkbox' ? 'change' : 'input';
      input.addEventListener(eventType, () => {
        const value = input.type === 'checkbox' ? (input.checked ? '1' : '0') : input.value;
        window.flutter_inappwebview.callHandler('onInputChange', {
          tag: input.id || '',
          value: value
        });
      });
    });

  document.body.style.userSelect = 'text';

  (function populateInputs() {
    const inputs = [${_textInputs.map((item) {
                final tag = item['TextTag'];
                final value = item['Value'] ?? '';
                return """{ tag: '$tag', value: `$value` }""";
              }).join(', ')}];

    inputs.forEach((input) => {
      const element = document.getElementById(input.tag);
      if (element) {
        if (element.type === 'checkbox') {
          element.checked = input.value === '1';
        } else if (element.tagName === 'TEXTAREA' || element.type === 'text') {
          element.value = input.value;
        }
      }
    });
  })();

  // Gérer les surlignages
const blockRanges = [${_blockRange.map((item) {
                final identifier = item['Identifier'] ?? 0;
                final startToken = item['StartToken'] ?? 0;
                final endToken = item['EndToken'] ?? 0;
                final colorIndex = item['ColorIndex'] ?? 0;
                return """{ identifier: $identifier, startToken: $startToken, endToken: $endToken, colorIndex: $colorIndex }""";
              }).join(', ')}];

const colors = ['#d3d3d3', '#ffff99', '#ccffcc', '#99ccff', '#ff99cc', '#ffcc99', '#cc99ff'];

blockRanges.forEach((range) => {
  const paragraph = document.querySelector(`[data-pid="${range.identifier}"]`);
  if (paragraph) {
   // print (range.identifier);
    const text = paragraph.innerText.split(' ');
    const highlightedText = text.map((word, index) => {
      if (index >= range.startToken && index < range.endToken) {
        return `<span style="background-color: colors[range.colorIndex % colors.length]};">word</span>`;
      }
      return word;
    }).join(' ');

    paragraph.innerHTML = highlightedText; // Applique le nouveau HTML
  }
});


// Gestion des clics hors paragraphe pour désélectionner
document.addEventListener('click', (event) => {
    if (!event.target.closest('p')) {
      document.querySelectorAll('p').forEach((p) => {
        p.classList.remove('jwac-textHighlight');
      });
    }
  });

  document.querySelectorAll('p').forEach((p) => {
    p.addEventListener('click', (event) => {
      const isAlreadySelected = p.classList.contains('jwac-textHighlight');
      document.querySelectorAll('p').forEach((p) => {
        p.classList.remove('jwac-textHighlight');
      });
      if (!isAlreadySelected) {
        p.classList.add('jwac-textHighlight');
        const paragraphId = p.getAttribute('data-pid') || '';
        const paragraphText = p.innerText || '';
        const x = event.clientX || 0;
        const y = event.clientY || 0;
        window.flutter_inappwebview.callHandler('onParagraphClick', paragraphId, paragraphText, x, y);
      }
    });
  });