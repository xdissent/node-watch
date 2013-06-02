fs = require 'fs'
path = require 'path'
tmp = require 'tmp'
watch = require '../index'

describe 'watch', ->
  @timeout 5000

  tmpDir = null
  timeout = null
  options =  maxInterval: 600

  mkfile = (name, callback) ->
    filename = path.join tmpDir, name
    fs.writeFile filename, 'testing', (err) ->
      setTimeout callback, timeout, filename if callback? and !err?

  beforeEach (done) ->
    timeout = 1
    tmp.dir (err, dir) ->
      return done err if err?
      tmpDir = dir
      done()

  it 'should not throw an exception when called without a callback', ->
    watch tmpDir, options

  it 'should not throw an exception when called without a callback or options', ->
    watch tmpDir

  it 'should throw an exception when called without a filename', ->
    watch.should.throw()

  it 'should throw an exception when called with an empty array', ->
    (-> watch []).should.throw()

  it 'should watch a single file', (done) ->
    changes = 0
    mkfile 'test', (filename) ->
      setTimeout ->
        watcher = watch filename, options, (filename) -> changes++

        fs.appendFile filename, 'test', (err) ->
          return done err if err?
          setTimeout ->
            changes.should.be.equal 1
            
            fs.appendFile filename, 'test', (err) ->
              return done err if err?

              setTimeout ->
                changes.should.be.equal 2
                watcher.close()
                done()
              , watcher.options.minInterval * 2
          , watcher.options.minInterval * 2
      , 100

  it 'should watch an array of files', (done) ->
    changes = 0
    mkfile 'test1', (file1) ->
      mkfile 'test2', (file2) ->
        setTimeout ->
          watcher = watch [file1, file2], options, (filename) -> changes++

          fs.appendFile file1, 'test', (err) ->
            return done err if err?

            setTimeout ->
              changes.should.be.equal 1
              
              fs.appendFile file2, 'test', (err) ->
                return done err if err?
                
                setTimeout ->
                  changes.should.be.equal 2
                  watcher.close()
                  done()
                , watcher.options.minInterval * 2
            , watcher.options.minInterval * 2
        , 100


  it 'should watch a directory recursively', (done) ->
    changes = 0
    level1 = path.join tmpDir, 'level1'
    level2 = path.join level1, 'level2'
    level3 = path.join level2, 'level3'
    level4 = path.join level3, 'level4'

    fs.mkdir level1, (err) ->
      return done err if err?
      setTimeout ->
        watcher = watch level1, options, (filename) -> changes++

        fs.mkdir level2, (err) ->
          return done err if err?

          changes.should.be.equal 0

          fs.mkdir level3, (err) ->
            return done err if err?

            changes.should.be.equal 0

            setTimeout ->
              fs.writeFile level4, 'testing', (err) ->
                return done err if err?

                setTimeout ->
                  changes.should.be.equal 1
                  done()
                , watcher.options.maxInterval
            , watcher.options.minInterval
      , 100

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