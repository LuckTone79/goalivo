const fs = require('fs');
const path = require('path');

const guidePath = path.join(__dirname, '..', 'guide.html');
const guideHtml = fs.readFileSync(guidePath, 'utf8');
const failures = [];

function expect(condition, message) {
  if (!condition) failures.push(message);
}

expect(
  guideHtml.includes('.decorative-overlay{position:absolute;pointer-events:none;z-index:0;}'),
  'Missing shared decorative overlay safety rule.'
);

expect(
  guideHtml.includes('.interactive-layer{position:relative;z-index:1;}'),
  'Missing shared interactive layer safety rule.'
);

expect(
  /<div class="decorative-overlay hero-overlay" aria-hidden="true"><\/div>/.test(guideHtml),
  'Hero decorative overlay is not isolated into an aria-hidden DOM layer.'
);

expect(
  /<div class="interactive-layer">[\s\S]*id="heroStartLink"[\s\S]*id="shareGuideButton"[\s\S]*<\/div>\s*<\/header>/.test(guideHtml),
  'Hero CTA and share button are not wrapped inside the interactive layer.'
);

expect(
  !guideHtml.includes('.hero::before'),
  'Legacy pseudo-element hero overlay still exists.'
);

expect(
  /id="heroStartLink"[^>]*target="_blank"[^>]*rel="noopener noreferrer"/.test(guideHtml),
  'Hero start link is missing required new-tab safety attributes.'
);

expect(
  /async function copyGuideLink\(\)/.test(guideHtml) &&
    /document\.getElementById\('shareGuideButton'\)\?\.addEventListener\('click'/.test(guideHtml),
  'Guide share button wiring is incomplete.'
);

if (failures.length) {
  console.error('Guide click-safety verification failed:\n');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log('Guide click-safety verification passed.');
