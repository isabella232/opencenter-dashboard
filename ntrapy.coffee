# Globals
fs = require "fs"
path = require "path"
http = require "http"
https = require "https"
gzippo = require "gzippo"
express = require "express"
request = require "request"
config = require "./config"
SQLiteStore = require("connect-sqlite3")(express)

# App
app = express()

# Config
app.configure ->
  app.set "port", process.env.PORT or 3000
  app.set "sport", process.env.SPORT or 3443
  app.set "views", __dirname + "/views"
  app.set "view engine", "jade"
  app.use express.favicon()
  app.use express.logger "dev"
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser config.secret
  app.use(express.session
    store: new SQLiteStore
      db: config.db
      dir: config.db_dir
    secret: config.secret
    cookie:
      maxAge: 24 * 60 * 60 * 1000) # one day
  app.use app.router

# Profiles
app.configure "production", ->
  # Use gzip/1 day cache
  app.use gzippo.staticGzip path.join __dirname, "public"
  app.use express.errorHandler()

app.configure "development", ->
  # no compression/no cache
  app.use express.static path.join __dirname, "public"
  app.use express.errorHandler
    dumpExceptions: true
    showStack: true

# Routes
app.get "/", (req, res) ->
  res.render "index",
    title: "nTrapy"

# TODO: Rewrite sessiony bits for MySQL

# API
app.post "/api/login", (req, res) ->
  #nano = require("nano") "http://localhost:5984"
  if not req.body.user? or not req.body.pass?
    res.send 401, "Missing user and/or pass!"
  else
    #nano.request
    #  method: "POST"
    #  db: "_session"
    #  form:
    #    name: req.body.user
    #    password: req.body.pass
    #  content_type: "application/x-www-form-urlencoded; charset=utf-8"
    #, (err, body, headers) ->
    #  if err
    #    res.send err.reason
    #  else
    #    if headers?["set-cookie"]
    #      res.cookie headers["set-cookie"]
    #    res.send "Logged in!"

app.post "/api/logout", (req, res) ->
  res.clearCookie "AuthSession"
  res.send "Logged out!"

app.all "/roush/?*", (req, res) ->
  req.pipe(request
    url: "https://localhost:8080/" + req?.params?[0]
    followRedirect: true
  ).pipe(res)

# HTTP server
http.createServer(app).listen app.get("port"), ->
  console.log "Express server listening on port " + app.get("port") + " in " + app.settings.env + " mode"

# TODO: See about stuffing this logic into callbacks on readFile
try
  # TLS setup
  tlsOptions =
    key: fs.readFileSync "key.pem"
    cert: fs.readFileSync "cert.pem"
  
  # HTTPS server
  https.createServer(tlsOptions, app).listen app.get("sport"), ->
    console.log "Express https server listening on port " + app.get("sport") + " in " + app.settings.env + " mode"

catch e
  console.log e
  console.log "Error setting up HTTPS; skipping."
