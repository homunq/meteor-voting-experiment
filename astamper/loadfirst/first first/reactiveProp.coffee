guid = ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
    r = Math.random()*16|0 
    v = if (c == 'x') then r else (r&0x3|0x8)
    v.toString(16)

class @Reactive
  constructor: (init, @name) ->
    if not @name
      @name = ''
    @name = @name + guid()
    @set init
    
  set: (val) ->
    if Session?
      Session.set @name, val
    
  get: ->
    if Session?
      Session.get @name
    
  equals: (val) ->
    if Session?
      Session.equals @name, val
