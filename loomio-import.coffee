#!/usr/bin/env coffee

require('sugar')
cheerio = require('cheerio')
cli     = require('cli').enable 'version', 'status'
nodefs  = require('fs')
util    = require('util')
Promise = require('promise')

#
#  Lib section
#

fs =
    read: Promise.denodeify(nodefs.readFile)
    write: Promise.denodeify(nodefs.writeFile)


crypto = require 'crypto'
hash = (text, length=8, key='thehashkey') ->
    h = crypto.createHash('sha1', key)
    h.update(text)
    h.digest('hex')[..length]


partial = (func, args...) ->
    func.bind(null, args...)


getRandomId = (length) ->
    chars = "0123456789abcdef"
    getChar = -> chars.charAt(Math.floor(Math.random() * chars.length))
    (getChar() for _ in [0..length]).join('')


sizeTo = (minLength, maxLength, text) ->
    if text.length < minLength
        "#{text}-#{getRandomId(text.length - minLength - 1)}"
    else if text.length > maxLength
        text[..maxLength]
    else
        text


buildLabel = (title, minLength=20, maxLength=80) ->
    label = title.toLowerCase().replace(/[^0-9a-z-]/g, '-').replace(/--+/g, '-')
    sizeTo(minLength, maxLength, label)


startTopic = ->
    statement: []
    feedback: []
    current: null


#
# End lib section
#


parseStatementPublishedDate = (doc) ->
    Date.create(
        doc('#discussion-context .discussion-additional-info')
            .clone().children().remove().end().text().trim()
            .replace('Started ', '').replace(' by', ''))


parseAuthor = (ele) ->
    id: ele.attr('href').toLowerCase().split('/')[2..].join('-')


buildDocument = (sections) ->
    sections.map (sectionText) ->
        id: hash(sectionText, 10)
        body: sectionText


# TODO: preserve <br />
fromParagraphs = (eles) ->
    (cheerio.load(ele)('p').text() for ele in eles)


parseStatement = (content) ->
    cli.info "Parsing statement from #{hash(content)}"
    topic = startTopic()
    doc = cheerio.load(content)

    title = doc('#discussion-title').children().remove().end().text().trim()

    statement =
        label: buildLabel(title)
        version:
            semantic: [1, 0, 0]
            details: "Imported from Loomio"
            "published-date": parseStatementPublishedDate(doc)
        authors: [parseAuthor(doc(
            '#discussion-context .discussion-additional-info a.user-name'))]
        title: title
        problem: buildDocument(["<see full text>"])
        full: buildDocument(
            fromParagraphs(
                doc('#discussion-context .long-description').children()))

    topic.statement.push statement
    topic


parseFeedback = (topic, content) ->
    cli.info "Parsing feedback from #{hash(content)}"
    feedback =
        id: ""
    topic.feedback.push feedback


cli.parse
    output: ['o', 'Write the output to this file', 'string']
    pretty: ['p', "Prettyprint the output JSON"]


# TODO: get author data as well
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
            data = JSON.stringify(topic, null, options.pretty and '  ')
            if options.output
                fs.write(options.output, data)
            else
                process.stdout.write(data)
                Promise.resolve(null)

        .done ->
            cli.info "Done"
