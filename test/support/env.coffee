fs = require 'fs'

try
  env = fs.readFileSync "#{__dirname}/../../.env", encoding: 'utf8'
  for e in (e.trim() for e in env.split "\n" when e.trim().length > 0)
    [k, v] = e.split "=", 2
    process.env[k] = v
catch err

process.env.NODE_ENV = 'test'