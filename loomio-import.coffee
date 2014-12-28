#!/usr/bin/env coffee 

cli = require('cli').enable 'version', 'status'
nodefs = require('fs')
Promise = require('promise')

# TODO: remove
crypto = require 'crypto'
hash = (text) ->
    h = crypto.createHmac('sha512', 'thekey')
    h.update(text)
    h.digest('hex')[..8]


fs =
    read: Promise.denodeify(nodefs.readFile)
    write: Promise.denodeify(nodefs.writeFile)


partial = (func, args...) ->
    func.bind(null, args...)


cli.parse
    output: ['o', 'Write the output to this file', 'string']


startTopic = ->
    {}

parseStatement = (content) ->
    cli.info "Parsing statement from #{hash(content)}"
    topic = startTopic()



parseFeedback = (topic, content) ->
    cli.info "Parsing feedback from #{hash(content)}"



cli.main (args, options) ->
    files = args[1..]

    cli.fatal "No files specified." if not files.length
    cli.info "Importing #{files.join(' ')}"
    cli.info "Writing to #{options.output}" if options.output

    fs.read(files[0])
        .then(parseStatement)
        .then (topic) ->
            Promise.all files.map (file) ->
                cli.info "Reading #{file}"
                fs.read(file)
            .then (contents) ->
                contents.map partial(parseFeedback, topic)
            .then ->
                Promise.resolve(topic)

        .then (topic) ->
            data = JSON.stringify(topic)
            if options.output
                fs.write(options.output, data)
            else
                process.stdout.write(data)
                Promise.resolve(null)
            
        .done ->
            cli.info "Done"
