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
    res.status(503).send(readFileSync('./index.html', 'utf8').replace('{{CORE_LOGS}}',
      readLogFile('/var/log/opencrvs.log')
    ).replace('{{COUNTRY_CONFIG_LOGS}}',
      readLogFile('/var/log/countryconfig.log')
    ))
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
    const url = new URL(req.headers.referer)

    const configWithProxyUrls = {
      ...config,
      API_GATEWAY_URL: `${url.protocol}//${req.headers.host}/gateway/`,
      CONFIG_API_URL: `${url.protocol}//${req.headers.host}/config/`,
      AUTH_URL: `${url.protocol}//${req.headers.host}/auth/`,
      AUTH_API_URL: `${url.protocol}//${req.headers.host}/auth/`,
      LOGIN_URL: `${url.protocol}//${req.headers.host}/login`,
      COUNTRY_CONFIG_URL: `${url.protocol}//${req.headers.host}/countryconfig`,
      MINIO_BUCKET: process.env.MINIO_BUCKET,
    }
    res.setHeader('Content-Type', 'application/javascript')
    res.send(`window.config = ${JSON.stringify(configWithProxyUrls, null, 2)}`)
  }
)
app.use(
  '/login-config.js', async (req, res) => {
    const config = await getClientConfig('http://localhost:3040/login-config.js')
    const url = new URL(req.headers.referer)

    const configWithProxyUrls = {
      ...config,
      CONFIG_API_URL: `${url.protocol}//${req.headers.host}/config/`,
      AUTH_API_URL: `${url.protocol}//${req.headers.host}/auth/`,
      CLIENT_APP_URL: `${url.protocol}//${req.headers.host}`,
      COUNTRY_CONFIG_URL: `${url.protocol}//${req.headers.host}/countryconfig`,
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
