fs = require 'fs'
path = require 'path'
events = require 'events'
util = require 'util'

try
  debug = require('debug') 'watch:watcher'
catch err
  debug = ->

class Watcher extends events.EventEmitter
  @types: ['File', 'Directory', 'SymbolicLink']

  @defaults: 
    recursive: true
    followSymLinks: false
    maxSymLevel: 1
    minInterval: 200
    maxInterval: 1000

  constructor: (@filenames, @options={}, @callback) -> 
    debug "constructor: #{@filenames}"
    throw new Error 'Filename required' unless @filenames? and @filenames.length > 0

    if typeof @options is 'function'
      @callback = @options
      @options = {}
    @options[k] = v for k, v of @constructor.defaults when !@options[k]
    debug "options: #{([k, v].join ': ' for k, v of @options).join ', '}"

    @callback ?= ->
    @watchers = {}
    @_changed = []
    @closed = false

    @filenames = [@filenames] unless util.isArray @filenames
    @watch f for f in @filenames

  close: ->
    w.close() for f, w of @watchers
    @watchers = {}
    @closed = true

  watch: (filename) ->
    return null if @closed
    return null unless fs.existsSync filename
    return null if @isSym(filename) and @options.maxSymLevel-- and !@_followSym()
    filename = path.resolve filename
    debug "watching #{filename}"
    @watchers[filename].close() if @watchers[filename]?
    @watchers[filename] = @_createWatcher filename
    if @options.recursive and @isDir filename
      fs.readdir filename, (err, files) =>
        @watch path.join filename, f for f in files when @isDir path.join filename, f

  _followSym: -> @options.followSymLinks and @options.maxSymLevel > 0

  _eventCallback: (evt) -> => @emit evt, arguments...

  _createWatcher: (filename) ->
    if @isDir filename
      callback = @_watchDirCallback filename
    else
      callback = @_watchFileCallback filename
      filename = path.resolve filename, '..'
    watcher = fs.watch filename, callback
    watcher.on 'change', @_eventCallback 'change'
    watcher.on 'error', @_eventCallback 'error'
    watcher

  _watchFileCallback: (watchFile) ->
    (evt, filename) =>
      debug "_watchFileCallback #{evt}, #{filename}"
      @_changedCallback watchFile if path.basename(watchFile) is filename

  _watchDirCallback: (parent) ->
    (evt, filename) =>
      fullPath = path.join parent, filename
      debug "_watchDirCallback #{evt}, #{fullPath}"
      @watch fullPath if evt is 'rename' and @isDir fullPath
      @_changedCallback fullPath unless @isDir fullPath

  _changedCallback: (filename) ->
    debug "_changedCallback #{filename}"
    debug '_minTimeout cancelled' if @_minTimeout?
    clearTimeout @_minTimeout
    @_minTimeout = null

    @_changed.push filename unless filename in @_changed

    @_minTimeout = setTimeout =>
      debug '_minTimeout'
      clearTimeout @_maxTimeout
      @_timeoutCallback()
    , @options.minInterval

    @_maxTimeout ?= setTimeout =>
      debug '_maxTimeout'
      clearTimeout @_minTimeout
      @_timeoutCallback()
    , @options.maxInterval

  _timeoutCallback: ->
      debug '_timeoutCallback'
      @callback f for f in @_changed when !@closed
      @_changed = []
      @_minTimeout = null
      @_maxTimeout = null


checkFileType = (type, filename) ->
  return false unless fs.existsSync filename
  fsMethod = if type is 'SymbolicLink' then 'lstatSync' else 'statSync'
  fs[fsMethod](filename)["is#{type}"]()

for t in Watcher.types
  do (t) -> Watcher.prototype["is#{t[0...3]}"] = (f) -> checkFileType t, f

Watcher.prototype.isFile = Watcher.prototype.isFil

module.exports = Watcher