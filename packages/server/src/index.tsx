import { dirname, join } from 'path';
import express from 'express';
import compression from 'compression';
import React from 'react';
import ReactDOMServer from 'react-dom/server';
import { App } from '@sample/app';

const app = express();
const port = 3000;

const appRootDirectory = dirname(require.resolve('@sample/app/package.json'));
const appBundleDirectory = join(appRootDirectory, 'umd');

app.use(compression());
app.use(express.static(appBundleDirectory));

app.get('/server', (_req, res) => {
    res.send(
        `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <meta name="Description" content="Monorepo example server-side renderer app">
    <title>Monorepo Example</title>
    <link href="main.css" rel="stylesheet">
</head>
<body>
    <div id="SITE_MAIN" data-ssr>
      ${ReactDOMServer.renderToString(<App text="Hello World (SSR!)" />)}
    </div>
    <script type="text/javascript" src="main.js"></script>
</body>
</html>`
    );
    res.end();
});

app.listen(port, () => {
    console.log(`Listening on:`);
    console.log(`  http://localhost:${port}/ - client only rendering`);
    console.log(`  http://localhost:${port}/server - ssr with hydration`);
});
