# require hapt.js, underscore.js

_settings = null

callbg = (cb, fnname, args...) ->
    chrome.runtime.sendMessage {type: 'call', fnname: fnname, args: args}, (response) ->
        cb?(response)

callbgcb = (cb, fnname, args...) ->
    chrome.runtime.sendMessage {type: 'callWithCallback', fnname: fnname, args: args}, (response) ->
        cb?(response)

haptListen = (cb) ->
    hapt.listen( (keys, event) ->
        if not (event.target.isContentEditable or event.target.nodeName.toLowerCase() in ['textarea', 'input', 'select'])
            return cb(keys, event)
        return true
    , window, true, [])

chrome.runtime.sendMessage {type: 'getSettings'}, (settings) ->
    _settings = settings

    hapt_listener = haptListen (_keys) ->
        keys = _keys.join(' ')
        if keys in (binding.join(' ') for binding in _settings.bindings.enter_select_mode)
            if not SelectMode.get().isEntered()
                SelectMode.get().enter()
                return
        if keys in (binding.join(' ') for binding in _settings.bindings.quit_select_mode)
            if SelectMode.get().isEntered()
                SelectMode.get().quit()
                return

chrome.runtime.onMessage.addListener (message, sender, sendResponse) ->
    switch message.type
        when 'toggleSelectMode'
            SelectMode.get().toggle()


class SelectMode
    instance = null

    # get singleton instance
    @get: ->
        instance ?= new _SelectMode

    class _SelectMode
        BACK_PANEL_ID = 'moly_scopping_search_backpanl'
        SUB_PANEL_CLASS_NAME = 'moly_scopping_search_subpanel'
        CENTER_PANEL_CLASS_NAME = 'moly_scopping_search_centerpanel'

        constructor: ->
            @backpanel = null
            @subpanels = null
            @rect = null

        enter: =>
            if @backpanel? then return
            @backpanel = document.createElement('div')
            @backpanel.id = BACK_PANEL_ID
            document.querySelector('body').appendChild(@backpanel)

            @rect = {left: 0, top: 0, right: 0, bottom: 0}
            setRect = (rect) =>
                [@rect.left, @rect.right] = if rect.left < rect.right then [rect.left, rect.right] else [rect.right, rect.left]
                [@rect.top, @rect.bottom] = if rect.top < rect.bottom then [rect.top, rect.bottom] else [rect.bottom, rect.top]

            setElementRect = (element, rect) =>
                element.style.left = rect.left + 'px'
                element.style.top = rect.top + 'px'
                element.style.width = rect.right - rect.left + 'px'
                element.style.height = rect.bottom - rect.top + 'px'

            drawBackPanel = =>
                if not @subpanels?
                    createSubPanel = =>
                        panel = document.createElement('div')
                        panel.className = SUB_PANEL_CLASS_NAME
                        @backpanel.appendChild(panel)
                        return panel
                    @subpanels = (createSubPanel() for i in _.range(4))

                setElementRect(@subpanels[0], {left: 0, top: 0, right: @rect.right, bottom: @rect.top})
                setElementRect(@subpanels[1], {left: 0, top: @rect.top, right: @rect.left, bottom: @backpanel.offsetHeight})
                setElementRect(@subpanels[2], {left: @rect.right, top: 0, right: @backpanel.offsetWidth, bottom: @rect.bottom})
                setElementRect(@subpanels[3], {left: @rect.left, top: @rect.bottom, right: @backpanel.offsetWidth, bottom: @backpanel.offsetHeight})

            centerpanel = null
            drawCenterPanel = =>
                if not centerpanel?
                    centerpanel = document.createElement('div')
                    centerpanel.className = CENTER_PANEL_CLASS_NAME
                    @backpanel.appendChild(centerpanel)
                setElementRect(centerpanel, @rect)

            dispatchRect = =>
                chrome.runtime.sendMessage({type: 'dispatchRect', rect: @rect, devicePixelRatio: window.devicePixelRatio, new_tab: _settings.do_search_on_new_tab})

            drawBackPanel()

            mousedown_listener = (e) =>
                start_point = {x: e.clientX, y: e.clientY}
                setRect({left: start_point.x, top: start_point.y, right: start_point.x, bottom: start_point.y})
                drawBackPanel()
                drawCenterPanel()
                @backpanel.removeEventListener('mousedown', mousedown_listener)

                mousemove_listener = (e) =>
                    point = {x: e.clientX, y: e.clientY}
                    setRect({left: start_point.x, top: start_point.y, right: point.x, bottom: point.y})
                    drawBackPanel()
                    drawCenterPanel()
                @backpanel.addEventListener('mousemove', mousemove_listener)

                mouseup_listener = (e) =>
                    end_point = {x: e.clientX, y: e.clientY}
                    setRect({left: start_point.x, top: start_point.y, right: end_point.x, bottom: end_point.y})
                    drawBackPanel()
                    drawCenterPanel()
                    @backpanel.removeEventListener('mousemove', mousemove_listener)
                    @backpanel.removeEventListener('mouseup', mouseup_listener)
                    dispatchRect()
                    @quit()
                @backpanel.addEventListener('mouseup', mouseup_listener)

            @backpanel.addEventListener('mousedown', mousedown_listener)

        quit: =>
            if not @backpanel? then return
            document.querySelector('body').removeChild(@backpanel)
            @backpanel = @subpanels = @rect = null

        toggle: =>
            if @backpanel?
                @quit()
            else
                @enter()

        isEntered: =>
            return @backpanel?
