{@app} = require('zappajs') -> 
    @configure =>
      @use 'bodyParser', 'methodOverride', @app.router, 'static'
      @set 'basepath': '/v1.0'

    @configure
      development: => @use errorHandler: {dumpExceptions: on, showStack: on}
      production: => @use 'errorHandler'

    @enable 'serve jquery', 'minify'

    uuid = require('node-uuid')
    db   = require('dirty') '/tmp/cloudflash.db'

    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'
    exec = require('child_process').exec

    db.on 'load', ->
        console.log 'loaded cloudflash.db'

    @get '/services': ->
        res = { 'services': [] }
        db.forEach (key,val) ->
            console.log 'found ' + key
            res.services.push val
        @send res

    @post '/services': ->
        return @next new Error "Invalid service posting!" unless @body.service and @body.service.pkgurl

#        @body.service.pkgurl = 'http://www.google.com/images/srpr/logo3w.png'

        # let's download this file from the web
        id = uuid.v4()
        filename = "/tmp/#{id}.pkg"
        webreq(@body.service.pkgurl, (error, response, body) =>
            # 1. verify that file has been downloaded
            # 2. dpkg -i filename
            # 3. verify that package has been installed
            # 4. return success message back
            return @next new Error "Unable to download service package!" if error

            console.log "checking for service package at #{filename}"
            if path.existsSync filename
                console.log 'found service package, issuing dpkg -i'
                exec "dpkg -i #{filename}", (error, stdout, stderr) =>
                    return @next new Error "Unable to install service package!" if error

                    @body.service.id = id
                    db.set id, @body, =>
                    console.log "#{@body.service.pkgurl} downloaded and installed successfully as service ID: #{id}"
                    @send @body
            else
                return @next new Error "Unable to download and install service package!"
            ).pipe(fs.createWriteStream(filename))
    
    @post '/openvpnpost': ->
        return @next new Error "Invalid service openvpn posting!" unless @body.openvpnpost and @body.openvpnpost.openvpnpostdata
        console.log "here in openvpnpost"
        console.log @body.openvpnpost
        id = uuid.v4()
        #{ form: @body }
    
    # helper routine for retrieving service data from dirty db
    loadService = ->
        console.log "loading service ID: #{@params.id}"
        service = db.get @params.id
        if service
            @body.service ?= service
            @next()
        else
            @next new Error "No such service ID: #{@params.id}"

    @get '/services/:id', loadService, ->
        @send @body

    @put '/services/:id', loadService, ->
        @body.service.id = @params.id
        # can have intelligent merge here

        db.set @params.id, @body, ->
            console.log "updated service ID: #{@params.id}"
            @send @body
            # do some work

    @del '/services/:id', loadService, ->
        db.rm @params.id, ->
            console.log "removed service ID: #{@params.id}"
            @send ''
            # do some work

    # @include 'firewall'

    # @include 'openvpn'

    #  this is where all openvpn code goes

#
#sample program
#

    @get '/': ->
        @render index: {title: 'cloudflash', layout: no}
        
	
    @on 'set nickname': ->
        @client.nickname = @data.nickname

    @on serviceadded: ->
        @broadcast said: {nickname: @client.nickname, text: @data.text}
        @emit said: {nickname: @client.nickname, text: @data.text}
        
    @get '/openvpn': ->
        @render openvpn: {title: 'cloudflash opnvpnpost', layout: no}

    @on serviceadded1: ->
        @broadcast said: {nickname: @client.nickname, text: @data.text}
        @emit said: {nickname: @client.nickname, text: @data.text}

    @client '/index.js': ->
        @connect()

        @on serviceadded: ->
          $('#panel').append "<p>#{@data.service.name} said: #{@data.service.id}</p>"

        $ =>
#          @emit 'set nickname': {nickname: prompt 'Pick a nickname!'}

          $('#box').focus()

          $('button').click (e) =>
            data = { 'service': $('#services').serializeFormJSON() }
            json = JSON.stringify(data)
            $.ajax
                type: "POST"
                url: '/services'
                data: json
                contentType: "application/json; charset=utf-8"
                success: (data) =>
                    @emit serviceadded: { text: $('#box').val() }


            e.preventDefault()
            
      @client '/openvpn.js': ->
        @connect()

        @on serviceadded1: ->
          $('#panel').append "<p>#{@data.openvpnpost.openvpnpostdata} said: #{@data.openvpnpost.id}</p>"

        $ =>

          $('#box').focus()

          $('button').click (e) =>
            alert 'openvpn'
            data = { 'openvpnpost': $('#openvpnpost').serializeFormJSON() }
            #data =  $('#openvpnpost').serializeFormJSON()
            json = JSON.stringify(data)
            alert 'data:' + data
            alert 'json:' + json
            $.ajax
                type: "POST"
                url: '/openvpnpost'
                data: json
                contentType: "application/json; charset=utf-8"
                success: (data) =>
                    @emit serviceadded1: { text: $('#box').val() }


            e.preventDefault()

    @view index: ->
        doctype 5
        html ->
          head ->
            title 'CloudFlash Test Application!'
            script src: '/socket.io/socket.io.js'
            script src: '/zappa/jquery.js'
            script src: '/zappa/zappa.js'
            script src: '/jquery-json.js'
            script src: '/index.js'
          body ->
            div id: 'panel'
            form '#services', ->
                p ->
                    span 'Service Name: '
                    input '#name'
                        type: 'text'
                        name: 'name'
                        value: 'iptables'
                p ->
                    span 'Service Type: '
                    input '#type',
                        type: 'text'
                        name: 'type'
                        value: 'firewall'
                p ->
                    span 'Package URL: '
                    input '#pkgurl',
                        type: 'text'
                        name: 'pkgurl'
                        value: 'http://www.getmyfireall.here.com'
                button 'Send'

     @view openvpn: ->
          doctype 5
          html ->
            head ->
              title 'CloudFlash Test Application!'
              script src: '/socket.io/socket.io.js'
              script src: '/zappa/jquery.js'
              script src: '/zappa/zappa.js'
              script src: '/jquery-json.js'
              script src: '/openvpn.js'
            body ->
              div id: 'panel'
              form '#openvpnpost', ->
                  p ->
                      span 'Openvpn Input: '
                      input '#openvpnpostdata'
                          type: 'text'
                          name: 'openvpnpostdata'
                          value: ''
                 
                  button 'Send'              
