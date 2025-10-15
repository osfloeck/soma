'''
assets.py
Default styling for new sites
Author: Oskar Floeck
Date: 15-10-2025
License: MIT
'''

DEFAULT_CSS = '''
/* Font faces */
@font-face {
 font-family: 'CMU Serif';
 src: url('/assets/fonts/cmunrm.otf') format('opentype');
 font-weight: normal;
 font-style: normal;
 font-display: swap;
}

@font-face {
 font-family: 'CMU Serif';
 src: url('/assets/fonts/cmunti.otf') format('opentype');
 font-weight: normal;
 font-style: italic;
 font-display: swap;
}

@font-face {
 font-family: 'CMU Serif';
 src: url('/assets/fonts/cmunbx.otf') format('opentype');
 font-weight: bold;
 font-style: normal;
 font-display: swap;
}

@font-face {
 font-family: 'CMU Serif';
 src: url('/assets/fonts/cmunbi.otf') format('opentype');
 font-weight: bold;
 font-style: italic;
 font-display: swap;
}

/* Reset and base styles */
* {
 margin: 0;
 padding: 0;
 box-sizing: border-box;
}

/* Typography */
body {
 font-family: 'CMU Serif', 'Georgia', 'Times New Roman', serif;
 line-height: 1.6;
 color: #333;
 max-width: 800px;
 margin: 0 auto;
 padding: 20px;
 background-color: #fff;
}

/* Navigation */
nav {
 margin-bottom: 2rem;
 padding-bottom: 1rem;
 border-bottom: 1px solid #eee;
}

nav a {
 margin-right: 1.5rem;
 text-decoration: none;
 color: #007acc;
 font-weight: 500;
}

nav a:hover {
 color: #005a9e;
}

/* Content */
.content {
 margin-bottom: 2rem;
}

.content h1 {
 font-size: 2.5rem;
 margin-bottom: 1rem;
 color: #222;
}

.content h2 {
 font-size: 1.8rem;
 margin: 1.5rem 0 1rem 0;
 color: #333;
}

.content p {
 margin-bottom: 1rem;
}

.content ul, .content ol {
 margin: 1rem 0;
 padding-left: 2rem;
}

.content li {
 margin-bottom: 0.5rem;
}

.content a {
 color: #007acc;
 text-decoration: none;
}

.content a:hover {
 text-decoration: underline;
}

/* Back link */
.back-link {
 display: inline-block;
 margin-top: 2rem;
 padding: 0.5rem 1rem;
 background-color: #f5f5f5;
 border-radius: 4px;
}

/* Responsive */
@media (max-width: 768px) {
 body {
 padding: 15px;
 }
 .content h1 {
 font-size: 2rem;
 }
 nav a {
 margin-right: 1rem;
 display: inline-block;
 margin-bottom: 0.5rem;
 }
}
'''

DEFAULT_ASSETS = {
'css/style.css': DEFAULT_CSS
}