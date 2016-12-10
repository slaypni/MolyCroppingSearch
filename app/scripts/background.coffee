# require underscore.js

search = (canvas, cb) ->
    URL = 'https://www.google.com/searchbyimage/upload'

    {mime: mime, data: png} = canvas2png(canvas)

    data = new Uint8Array(png.length)
    for i in _.range(png.length)
        data[i] = png.charCodeAt(i)
    blob = new Blob([data], {type: mime})

    formdata = new FormData()
    formdata.append('encoded_image', blob, '')
    formdata.append('image_content', '')

    xhr = new XMLHttpRequest()
    xhr.open('POST', URL, true)
    xhr.onload = ->
        url = xhr.getResponseHeader('location')

    chrome.webRequest.onHeadersReceived.addListener(
        (details) ->
            header = _.findWhere(details.responseHeaders, {name: 'location'})
            cb?(header.value) if header?
            chrome.webRequest.onHeadersReceived.removeListener(arguments.callee)
        , {
            urls: [URL]
            types: ['xmlhttprequest']
        }
        , ['responseHeaders']
    )

    xhr.send(formdata)


canvas2png = (canvas) ->
    dataurl = canvas.toDataURL()
    m = dataurl.match(/data:(.+?)(;base64)?,/)
    mime = m[1]
    data = atob(dataurl[m[0].length..])
    return {mime: mime, data: data}


chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    getFunction = ->
        obj = window
        for prop in request.fnname.split('.')
            obj = obj[prop]
        return obj

    switch request.type
        when 'call'
            fn = getFunction()
            response = fn.apply(this, request.args)
            sendResponse(response)
        when 'callWithCallback'
            fn = getFunction()
            fn.apply(this, request.args.concat(sendResponse))
        when 'getTab'
            sendResponse(sender.tab)
        when 'getSettings'
            storage.getSettings (settings) ->
                sendResponse(settings)
        when 'setSettings'
            storage.setSettings request.settings, (settings) ->
                sendResponse(settings)
        when 'dispatchRect'
            rect = request.rect
            chrome.windows.getCurrent (window) ->
                chrome.tabs.captureVisibleTab window.id, {format: 'png'}, (dataUrl) ->
                    image = document.createElement('img')
                    image.src = dataUrl
                    image.onload = ->
                        devicePixelRatio = request.devicePixelRatio
                        right = rect.right * devicePixelRatio
                        left = rect.left * devicePixelRatio
                        bottom = rect.bottom * devicePixelRatio
                        top = rect.top * devicePixelRatio
                        width = right - left
                        height = bottom - top
                        canvas = document.createElement('canvas')
                        canvas.width = width
                        canvas.height = height
                        context = canvas.getContext('2d')
                        context.drawImage(image, left, top, width, height, 0, 0, width, height)
                        search canvas, (url) ->
                            if request.new_tab
                                chrome.tabs.create({index: sender.tab.index + 1, url: url})
                            else
                                chrome.tabs.update(sender.tab.id, {url: url})

    return true


chrome.browserAction.onClicked.addListener (tab) ->
    chrome.tabs.sendMessage(tab.id, {type: 'toggleSelectMode'})
