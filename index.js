const express = require('express')
const { createProxyMiddleware, responseInterceptor } = require('http-proxy-middleware')
const { readFileSync } = require('fs')
const app = express()
const axios = require('axios');

let stackReady = false;

async function getClientConfig() {
  const config = await axios.get('http://localhost:3040/login-config.js')
  const window = {}
  eval(config.data);
  return window.config;
}

function readLogFile(filePath) {
  try {
    return readFileSync(filePath, 'utf8')
  } catch (error) {
    return `No log file ${filePath} found`
  }
}

app.use('/var/log/:file', (req, res) => {
  res.send(readFileSync(`/var/log/${req.params.file}`, 'utf8'))
})

app.use(async (req, res, next) => {
  if (stackReady) {
    return next()
  }

  if (req.path.includes('/var/log/')) {
    return next
  }

  try {
    await Promise.all([
      axios.get('http://localhost:3040/ping'),
      axios.get('http://localhost:3020'),
      axios.get('http://localhost:3000')
    ])
    stackReady = true;
    next()
  } catch (error) {
    res.status(503).send(`
    <html>
      <head>
        <title>Stack not ready</title>
        <meta http-equiv="refresh" content="5" >
        <style>
        body {
          font-family: 'Georgia', serif; /* A more elegant font for the festive theme */
          background-color: #145214; /* A rich, dark green background */
          color: #FF0000; /* Bright red text color for the Christmas vibe */
        }
        h1, p, a {
          color: #FFD700; /* Gold color for headings and links */
        }
        .logs {
          display: grid;
          grid-template-columns: 1fr 1fr;
          grid-gap: 1rem;
        }
        section {
          border: 2px solid #FFD700; /* Gold border for log sections */
          background-color: #145214;
          padding: 1rem;
          overflow: auto;
          max-height: 500px;
          display: flex;
          flex-direction: column-reverse;
        }
        pre {
          margin: 0;
          color: #FFFFFF; /* White for preformatted text */
          white-space: pre-wrap; /* Ensures logs do not overflow */
        }
        a {
          color: #FFD700;
          text-decoration: none; /* Optional: removes underlining of links */
        }
        a:hover {
          color: #FF6347; /* A warm red color for hover states */
        }
      </style>
      </head>
      <body>
        <h1>Stack not ready</h1>
        <p>Waiting for the stack to be ready. This shouldn't take more than a few minutes.</p>
        <p><strong>Build logs and core logs:</strong></p>
        <div class="logs">
        <section>
        <pre>${readLogFile('/var/log/opencrvs.log')}</pre>
        </section>
        <section>
        <pre>${readLogFile('/var/log/countryconfig.log')}</pre>
      </section>
        </div>
        <p><strong>More logs:</strong></p>
        <ul>
          <li><a href="/var/log/opencrvs_stderr.log">/var/log/opencrvs_stderr.log</a></li>
          <li><a href="/var/log/opencrvs_stdout.log">/var/log/opencrvs_stdout.log</a></li>
          <li><a href="/var/log/countryconfig_stderr.log">/var/log/countryconfig_stderr.log</a></li>
          <li><a href="/var/log/countryconfig_stdout.log">/var/log/countryconfig_stdout.log</a></li>
          <li><a href="/var/log/elasticsearch_stderr.log">/var/log/elasticsearch_stderr.log</a></li>
          <li><a href="/var/log/elasticsearch_stdout.log">/var/log/elasticsearch_stdout.log</a></li>
          <li><a href="/var/log/hearth_stderr.log">/var/log/hearth_stderr.log</a></li>
          <li><a href="/var/log/hearth_stdout.log">/var/log/hearth_stdout.log</a></li>
          <li><a href="/var/log/influxdb_stderr.log">/var/log/influxdb_stderr.log</a></li>
          <li><a href="/var/log/influxdb_stdout.log">/var/log/influxdb_stdout.log</a></li>
          <li><a href="/var/log/minio_stderr.log">/var/log/minio_stderr.log</a></li>
          <li><a href="/var/log/minio_stdout.log">/var/log/minio_stdout.log</a></li>
          <li><a href="/var/log/mongodb_stderr.log">/var/log/mongodb_stderr.log</a></li>
          <li><a href="/var/log/mongodb_stdout.log">/var/log/mongodb_stdout.log</a></li>
          <li><a href="/var/log/openhim_stderr.log">/var/log/openhim_stderr.log</a></li>
          <li><a href="/var/log/openhim_stdout.log">/var/log/openhim_stdout.log</a></li>
          <li><a href="/var/log/proxy_stderr.log">/var/log/proxy_stderr.log</a></li>
          <li><a href="/var/log/proxy_stdout.log">/var/log/proxy_stdout.log</a></li>
          <li><a href="/var/log/redis_stderr.log">/var/log/redis_stderr.log</a></li>
          <li><a href="/var/log/redis_stdout.log">/var/log/redis_stdout.log</a></li>
        </ul>
      </body>
    `)
  }
})

app.use(
  '/sw.js',
  (req, res) => {
    res.setHeader('Content-Type', 'application/javascript')
    res.send("")
  }
)
app.use(
  '*/registerSW.js',
  (req, res) => {
    res.setHeader('Content-Type', 'application/javascript')
    res.send("")
  }
)
app.use(
  '/content/*',
  createProxyMiddleware({
    target: 'http://localhost:3040',
    changeOrigin: true
  })
)
app.use(
  '/publicConfig',
  createProxyMiddleware({
    target: 'http://localhost:2021',
    changeOrigin: true
  })
)
app.use(
  '/ocrvs',
  createProxyMiddleware({
    target: 'http://localhost:3535',
    changeOrigin: false
  })
)
app.use(
  '/auth',
  createProxyMiddleware({
    target: 'http://localhost:4040',
    changeOrigin: true,
    pathRewrite: {
      '^/auth': '/'
    }
  })
)
app.use(
  '/gateway',
  createProxyMiddleware({
    target: 'http://localhost:7070',
    changeOrigin: true,
    pathRewrite: {
      '^/gateway': '/'
    }
  })
)
app.use(
  '/.well-known',
  createProxyMiddleware({
    target: 'http://localhost:4040',
    changeOrigin: true
  })
)
app.use(
  '/graphql',
  createProxyMiddleware({
    target: 'http://localhost:7070',
    changeOrigin: true
  })
)
app.use(
  '/config',
  createProxyMiddleware({
    target: 'http://localhost:2021',
    changeOrigin: true,
    pathRewrite: {
      '^/config': '/'
    }
  })
)
app.use(
  '/countryconfig',
  createProxyMiddleware({
    target: 'http://localhost:3040/',
    changeOrigin: true,
    pathRewrite: {
      '^/countryconfig': '/'
    }
  })
)

app.use(
  '/client-config.js', async (req, res) => {
    const config = await getClientConfig('http://localhost:3040/client-config.js')
    const configWithProxyUrls = {
      ...config,
      API_GATEWAY_URL: `${req.protocol}://${req.headers.host}/gateway/`,
      CONFIG_API_URL: `${req.protocol}://${req.headers.host}/config/`,
      AUTH_URL: `${req.protocol}://${req.headers.host}/auth/`,
      LOGIN_URL: `${req.protocol}://${req.headers.host}/login`,
      COUNTRY_CONFIG_URL: `${req.protocol}://${req.headers.host}/countryconfig`,
      MINIO_BUCKET: process.env.MINIO_BUCKET,
    }
    res.setHeader('Content-Type', 'application/javascript')
    res.send(`window.config = ${JSON.stringify(configWithProxyUrls, null, 2)}`)
  }
)
app.use(
  '/login-config.js', async (req, res) => {
    const config = await getClientConfig('http://localhost:3040/login-config.js')

    const configWithProxyUrls = {
      ...config,
      CONFIG_API_URL: `${req.protocol}://${req.headers.host}/config/`,
      AUTH_API_URL: `${req.protocol}://${req.headers.host}/auth/`,
      CLIENT_APP_URL: `${req.protocol}://${req.headers.host}`,
      COUNTRY_CONFIG_URL: `${req.protocol}://${req.headers.host}/countryconfig`,
    }

    res.setHeader('Content-Type', 'application/javascript')
    res.send(`window.config = ${JSON.stringify(configWithProxyUrls, null, 2)}`)
  }
)


app.use(
  '/login',
  createProxyMiddleware({
    target: 'http://localhost:3020/',
    changeOrigin: true,
    pathRewrite: {
      '^/login': '/'
    },
    changeOrigin: true,
    selfHandleResponse: true,
    onProxyRes: responseInterceptor(async (responseBuffer, proxyRes, req, res) => {
      const response = responseBuffer.toString('utf8');
      if (req.url.endsWith('.js')) {
        return response
          .replace('http://localhost:3040/login-config.js', '/login-config.js')
          .replace('createBrowserHistory()', 'createBrowserHistory({basename: "/login"})')
      }
      if (req.path === '/') {
        return response
          .replace(/="\//g, '="/login/')
          .replace('http://localhost:3040/login-config.js', '/login-config.js')
      }

      return response
    })
  })
)

function isRedirectedFromLoginApp(req) {
  return req.headers.referer.includes('/login/step-two')
}

function isClient(_pathname, req) {
  return !req.headers.referer
    || !req.headers.referer.includes('/login')
    || isRedirectedFromLoginApp(req)
}

function isLogin(_pathname, req) {
  return req.headers.referer
    && req.headers.referer.includes('/login')
    && !isRedirectedFromLoginApp(req)
};


app.use(
  '/',
  createProxyMiddleware(isLogin, {
    target: 'http://localhost:3020/',
    changeOrigin: true,
    selfHandleResponse: true,
    onProxyRes: responseInterceptor(async (responseBuffer) => {
      const response = responseBuffer.toString('utf8');
      return response
    })
  })
)

app.use(
  '/*',
  createProxyMiddleware(isClient, {
    target: 'http://localhost:3000/',
    changeOrigin: true,
    selfHandleResponse: true,
    onProxyRes: responseInterceptor(async (responseBuffer, proxyRes, req, res) => {
      if (proxyRes.statusCode === 404) {
        try {
          const indexResponse = await axios.get('http://localhost:3000/index.html');
          res.setHeader('Content-Type', 'text/html');
          res.removeHeader('Content-Security-Policy');
          res.status(200);

          return indexResponse.data.replace('http://localhost:3040/client-config.js', '/client-config.js')
        } catch (error) {
          console.log(error);

          // Handle error if fetching index.html fails
          res.writeHead(500);
          res.end('Error fetching index page');
        }
      } else {
        // Else, handle the response as usual
        const response = responseBuffer.toString('utf8');
        return response.replace('http://localhost:3040/client-config.js', '/client-config.js');
      }
    })
  })
)


app.listen(7000)
