#TODO: static methods that can be inherited

@console ?=
  log: ->

class Field
  constructor: (default_val, @validator) ->
    if (_ default_val).isFunction() 
      @default = default_val
    else
      @default = ->
        if default_val is undefined
          return undefined
        JSON.parse(JSON.stringify(default_val)) #lazy deep copy, without needing type checks.
      
  invalid: (val) ->
    if @validator
      return !@validator val
    false
    
#Don't worry about stomping this variable inside a function, you'll never need it outside of a class declaration.
field = -> #just some sugar to save typing "new". 
  new Field arguments...
  
class StamperInstance
  #todo: getters/setters; hide actual values in _raw object
  constructor: (props) -> #=Meteor.is_client) ->
    props ?= {}
    if @_loose
      @_looseFields = []
    if @_fields
      for pname, prop of props
        if pname isnt "_id"
          if not @_fields[pname]?
            err = "Invalid property name: #{ pname } (#{ prop }) when constructing a #{ @constructor.name }"
            console.log "ERROR: ", err
            if @_strict
              throw new Error err
            if @_loose #keep extra fields and use them when saving
              @_looseFields.push pname
          else if @_fields[pname].invalid()
            throw new Error "Invalid property val: #{ pname } (#{ prop }) when constructing a #{ @constructor.name }"
      for fname, f of @_fields
        if not props[fname]?
          props[fname] = f.default(props)
    _.extend this, props
  
  @fields: (_fields) ->
    if @::_fields?
      @::_fields = _.clone @::_fields #copy from superclass to class.
    else
      @::_fields = {} #start with no fields
    
    for fname, f of _fields
      if not (f instanceof Field)
        f = new field f
      @::_fields[fname] = f
       
  @static: (fn) -> #for use inside @register
    fn.static = true
    fn
    
  @register: (methods) ->
    servermethods = {}
    self = this
    for mname, method of methods
      do -> #closure so that client-side method can sneak a reference to instance into the generic
            #Meteor.methods stub.
            #This technique isn't threadsafe but that's OK, no threads on client.
        cur_instance = undefined
        
        smname = self.name + "_" + mname
        if !method.static #instance
          servermethods[smname] = (id, obj, args...) ->
            console.log "server calling ", smname, "userId", @userId, "isServer", Meteor.isServer
            if Meteor.isServer
              cur_instance = self.prototype.collection.findOne
                _id: id
             
              if cur_instance
                cur_instance = new self cur_instance
              console.log "server method on", id, (cur_instance and "has cur_instance")
              #console.log self.prototype.collection.find().fetch()
            else
              cur_instance = obj
            if not cur_instance
              throw Meteor.Error 404, "No such object on #{ if Meteor.isServer then 'server'  else 'client' }"
              
            cur_instance.userId = @userId #sneak in a method for current userId
            cur_instance[smname].apply cur_instance, args
        else #static
          servermethods[smname] = (args...) ->
            console.log "server calling static ", smname, "userid", @userId
            self.userId = @userId #sneak in a method for current userId
            #console.log "Crashy?", smname
            #console.log self
            #console.log self.constructor
            #console.log self.prototype
            
            #console.log self.__proto__
            self[smname] args...
            
        if method.static
          goesOn = self
        else
          goesOn = self.prototype
        if Meteor.is_client 
          do (method, smname) ->
            #console.log "adding method ", mname, " to ", goesOn, "!!!!!!!!!!!!!!!!!!!!!!!"
            goesOn[mname] = (args...) ->
              console.log "client calling ", smname
              if method.static
                Meteor.call smname, args...
              else
                Meteor.call smname, @_id, @, args...
        else
          goesOn[mname] = method
        goesOn[smname] = method
    Meteor.methods servermethods
    
  raw: ->
    
    fields = ['_id']
    if @_looseFields
      fields = fields.concat @._looseFields
    if @_fields
      fields = fields.concat _.keys @_fields
      return _.pick @, fields
    @
  #@from: (props) ->
  #  props.
    
  save: (cb) ->
    console.log "save: ", @_id, @::, @collection._name
    if @_id
      raw = @raw()
      #console.log "resave raw: ", raw
      @collection.update
        _id: @_id
      , raw, cb
      return @_id
    else
      x = @raw()
      console.log "raw: ", x
      returnv= @collection.insert @raw(), (error, result)=>
        if !error and result
          @_id = result
        console.log "saved", result, @_id
        if cb
          cb error, result
      console.log returnv
      if returnv
        @_id = returnv
      returnv
          
  remove: (cb) ->
    @collection.remove
      _id: @_id
    , cb
    
class StamperCursor #extends Meteor.Collection.Cursor
  constructor: (@cursor, @object) ->
    
  forEach: (cb) ->
    console.log "foreach outer"
    @cursor.forEach (item) ->
      console.log "foreach inner"
      cb new @object item
      
  map: (cb) ->
    console.log "map outer"
    @cursor.map (item) ->
      console.log "map inner"
      cb new @object item
      
  fetch: ->
    console.log "fetch outer"
    (new @object item) for item in @cursor.fetch()
    
  count: ->
    console.log "count outer"
    @cursor.count()
    
  rewind: ->
    console.log "rewind outer"
    @cursor.rewind()
    
  observe: (cbs) ->
    console.log "observe outer"
    itype = @object
    if cbs.added
      do (cb = cbs.added) ->
        cbs.added = (doc, before_ind) ->
          console.log "observe added inner"
          console.log itype.name
          debugger
          #todo: client-side colletions.js lie 54: var doc = self._collection.findOne(msg.id);
          #this is called in a Meteor.Collection but doesn't get those updates in a StamperCollection right now... why not?'
          cb (new itype doc), before_ind
    if cbs.changed
      do (cb = cbs.changed) ->
        cbs.changed = (new_doc, at_ind, old_doc) ->
          console.log "observe changed inner"
          cb (new itype new_doc), before_ind, (new @object old_doc)
    if cbs.moved
      do (cb = cbs.moved) ->
        cbs.moved = (doc, old_ind, new_ind) ->
          console.log "observe moved inner"
          cb (new itype doc), old_ind, new_ind
    if cbs.removed
      do (cb = cbs.removed) ->
        cbs.removed = (old_doc, at_ind) ->
          console.log "observe removed inner"
          cb (new itype old_doc), at_ind
    @cursor.observe cbs
    
class StamperCollection extends Meteor.Collection
  constructor: (name, manager, @object) ->
    @collection = new Meteor.Collection name, manager
    @object.collection = @
  
  find: (selector, options) ->
    console.log "find outer"
    inner_cursor = @collection.find selector, options
    outer_cursor = new StamperCursor (inner_cursor), @object  
    outer_cursor.__proto__.__proto__ = inner_cursor.__proto__
    outer_cursor
  
  findOne: (selector, options) ->
    console.log "findone outer"
    result = @collection.findOne selector, options
    if result
      return new @object result
    result
  
  insert: (doc, cb) ->
    console.log "insert outer"
    if selector instanceof @object
      selector = selector.raw()
    @collection.insert doc, cb 
  
  update: (selector, modifier, options, cb) ->
    console.log "update outer"
    if selector instanceof @object
      selector = selector.id
    @collection.update selector, modifier, options, cb
  
  remove: (selector, cb) ->
    console.log "remove outer"
    if selector instanceof @object
      selector = selector.id
    @collection.remove selector, cb  
      
  
  