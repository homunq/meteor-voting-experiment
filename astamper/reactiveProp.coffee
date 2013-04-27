guid = ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
    r = Math.random()*16|0 
    v = if (c == 'x') then r else (r&0x3|0x8)
    v.toString(16)

class Reactive
  constructor: (init, @name) ->
    if not @name
      @name = ''
    @name = @name + guid()
    @set init
    
  set: (val) ->
    Session.set @name, val
    
  get: ->
    Session.get @name
    
  equals: (val) ->
    Session.equals @name, val
