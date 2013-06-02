fs = require 'fs'
path = require 'path'
tmp = require 'tmp'
watch = require '../index'

describe 'watch', ->

  tmpDir = null
  timeout = null
  options =  maxInterval: 600

  mkfile = (name, callback) ->
    fs.writeFile path.join(tmpDir, name), 'teeseting', (err) ->
      setTimeout callback, timeout if callback? and !err?

  beforeEach (done) ->
    timeout = 1
    tmp.dir (err, dir) ->
      return done err if err?
      tmpDir = dir
      done()

  it 'should batch change notifications by minInterval option', (done) ->
    changed = []
    watcher = watch tmpDir, options, (filename) -> changed.push filename

    setTimeout ->
      mkfile 'one', -> mkfile 'two', -> mkfile 'three'

      setTimeout ->
        changed.should.have.length 0
      , watcher.options.minInterval / 2

      setTimeout ->
        changed.should.have.length 3
        watcher.close()
        done()
      , watcher.options.minInterval * 2
    , 100

  it 'should force change notification at maxInterval option', (done) ->
    changed = []
    watcher = watch tmpDir, options, (filename) -> changed.push filename

    timeout = watcher.options.minInterval / 2
    setTimeout ->
      mkfile 'one', -> mkfile 'two', -> mkfile 'three', -> mkfile 'four', ->
        mkfile 'five', -> mkfile 'six', -> mkfile 'seven', -> mkfile 'eight', ->
          mkfile 'nine', -> mkfile 'ten', -> mkfile 'eleven', -> mkfile 'twelve'

      setTimeout ->
        changed.should.have.length 0
      , watcher.options.minInterval * 2

      setTimeout ->
        changed.should.have.length 5
      , watcher.options.maxInterval + watcher.options.minInterval

      setTimeout ->
        changed.should.have.length 12
        watcher.close()
        done()
      , watcher.options.maxInterval * 2 + watcher.options.minInterval * 2
    , 100