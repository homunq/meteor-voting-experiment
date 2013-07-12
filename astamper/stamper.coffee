#TODO: static methods that can be inherited

@console ?=
  log: ->

@DEBUG ?= true

debug = ->
  if DEBUG
    slog arguments...

class Field
  #used by StamperInstance::fields for basic ORM
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
      return not @validator val
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
            err = "Invalid property name: #{ pname } (#{ prop }) when constructing a #{ @constructor::__name__ }"
            slog "ERROR: ", err
            if @_strict
              throw new Error err
            if @_loose #keep extra fields and use them when saving
              @_looseFields.push pname
          else if @_fields[pname].invalid()
            throw new Error "Invalid property val: #{ pname } (#{ prop }) when constructing a #{ @constructor::__name__ }"
      for fname, f of @_fields
        if not props[fname]?
          props[fname] = f.default(props)
    _.extend this, props
  
  @fields: (_fields) ->
    #use this in the class declaration to give fields, validators, and/or defaults.
    if @::_fields?
      @::_fields = _.clone @::_fields #copy from superclass to class.
    else
      @::_fields = {} #start with no fields
    
    for fname, f of _fields
      if not (f instanceof Field)
        f = new field f
      @::_fields[fname] = f
       
  @static: (fn) -> #for use as a pseudo-decorator inside @register
    #simply paints the function object with a static flag, so it can be treated differently by @register
    fn.static = true
    fn
    
  @register: (methods) ->
    #use this inside the class declaration; hand it a hash of methods that should be executed server-side.
    servermethods = {}
    self = this
    for mname, method of methods
      do -> #closure so that client-side method can sneak a reference to instance into the generic
            #Meteor.methods stub.
            #This technique isn't threadsafe but that's OK, no threads on client.
        cur_instance = undefined
        
        if not self::__name__
          #Unfortunately, the class.name javascript property is not reliable in the face of minification.
          #it works for testing, but remind the developer to redeclare it explicitly before they enter production.
          slog ('Warning: Before you go into production, after "class '+self.name+
            '" you should add: "  __name__: \'' + self.name + '\'"')
            self::__name__ = self.name
        smname = self::__name__ + "_" + mname
        if !method.static #instance
          servermethods[smname] = (id, obj, args...) ->
            debug "server calling ", smname, "userId", @userId, "isServer", Meteor.isServer
            if Meteor.isServer
              cur_instance = self.prototype.collection.findOne
                _id: id
             
              if cur_instance
                cur_instance = new self cur_instance
              debug "server method on", id, (cur_instance and "has cur_instance")
            else
              cur_instance = obj
            if not cur_instance
              throw Meteor.Error 404, "No such object on #{ if Meteor.isServer then 'server'  else 'client' }"
              
            cur_instance.userId = @userId #sneak in a method for current userId
            cur_instance[smname].apply cur_instance, args
        else #static
          servermethods[smname] = (args...) ->
            debug "server calling static ", smname, "userid", @userId
            self.userId = @userId #sneak in a method for current userId
            self[smname] args...
            
        if method.static
          goesOn = self
        else
          goesOn = self.prototype
        if Meteor.is_client 
          do (method, smname) ->
            #slog "adding method ", mname, " to ", goesOn
            goesOn[mname] = (args...) ->
              debug "client calling ", smname, mname
              if method.static
                Meteor.call smname, args...
              else
                Meteor.call smname, @_id, @, args...
        else
          goesOn[mname] = method
        goesOn[smname] = method
    Meteor.methods servermethods
  
  @admin: ->
    #Call immediately after the class declaration
    #sets up an easy way to subscribe to an uncensored version of the collection, using a password declared elsewhere.
    @::collection.adminSubscribe = (password) => 
      if Meteor.isClient
        Meteor.subscribe @::collection._name + "_admin", password
    if Meteor.isServer
      Meteor.publish @::collection._name + "_admin", (password) =>
        slog password, PASSWORD #@::collection.find().fetch()
        if password is PASSWORD
          @::collection.find()
  
    
  invalid: ->
    #validate all fields of the object
    badFields = []
    for name, field of @_fields
      if field.invalid @[name]
        badFields.push field
    if badFields.length
      return badFields
    return no
    
  raw: ->
    #return a json-able copy of self; that is, without methods or temp properties.
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
    #save current value of self to DB
    slog "save: ", @_id, @::, @collection._name
    if @_id
      raw = @raw()
      #slog "resave raw: ", raw
      @collection.update
        _id: @_id
      , raw, cb
      return @_id
    else
      x = @raw()
      slog "raw: ", x
      returnv= @collection.insert @raw(), (error, result)=>
        if !error and result
          @_id = result
        slog "saved", result, @_id
        if cb
          cb error, result
      slog returnv
      if returnv
        @_id = returnv
      returnv
         
  reload: ->
    #reload properties from DB.
    #slog "reloading", @, @collection.findOne
    #  _id: @_id
    _.extend @, @collection.findOne
      _id: @_id
    
  inc: (incer, cb) -> #incer is a {field: inc} object
    if not @_id
      #can't atomically increment a record that's never been saved
      cb new Meteor.Error(404, "Can't atomically increment a record that's never been saved")
      return
    @collection.update
      _id: @_id
    , 
      $inc: incer
    , =>
      if cb
        @reload()
        cb()
  
  push: (pusher, cb) -> #pusher is a {field: item} object
    if not @_id
      #can't atomically push to a record that's never been saved
      cb new Meteor.Error(404, "Can't atomically push to a record that's never been saved")
      return
    @collection.update
      _id: @_id
    , 
      $push: pusher
    , =>
      if cb
        @reload()
        cb()
    
    
  pull: (puller, cb) -> #puller is a {field: item} object
    if not @_id
      #can't atomically pull from a record that's never been saved
      cb new Meteor.Error(404, "Can't atomically pull from a record that's never been saved")
      return
    @collection.update
      _id: @_id
    , 
      $pull: puller
    , =>
      if cb
        @reload()
        cb()
    
  remove: (cb) ->
    @collection.remove
      _id: @_id
    , cb
    
class StamperCursor #extends Meteor.Collection.Cursor
  constructor: (@cursor, @object) ->
    
  forEach: (cb) ->
    slog "foreach outer"
    @cursor.forEach (item) ->
      slog "foreach inner"
      cb new @object item
      
  map: (cb) ->
    slog "map outer"
    @cursor.map (item) ->
      slog "map inner"
      cb new @object item
      
  fetch: ->
    slog "fetch outer"
    (new @object item) for item in @cursor.fetch()
    
  count: ->
    slog "count outer"
    @cursor.count()
    
  rewind: ->
    slog "rewind outer"
    @cursor.rewind()
    
  observe: (cbs) ->
    slog "observe outer"
    itype = @object
    if cbs.added
      do (cb = cbs.added) ->
        cbs.added = (doc, before_ind) ->
          slog "observe added inner"
          slog itype::__name__
          debugger
          #todo: client-side colletions.js lie 54: var doc = self._collection.findOne(msg.id);
          #this is called in a Meteor.Collection but doesn't get those updates in a StamperCollection right now... why not?'
          cb (new itype doc), before_ind
    if cbs.changed
      do (cb = cbs.changed) ->
        cbs.changed = (new_doc, at_ind, old_doc) ->
          slog "observe changed inner"
          cb (new itype new_doc), before_ind, (new @object old_doc)
    if cbs.moved
      do (cb = cbs.moved) ->
        cbs.moved = (doc, old_ind, new_ind) ->
          slog "observe moved inner"
          cb (new itype doc), old_ind, new_ind
    if cbs.removed
      do (cb = cbs.removed) ->
        cbs.removed = (old_doc, at_ind) ->
          slog "observe removed inner"
          cb (new itype old_doc), at_ind
    @cursor.observe cbs
    
class StamperCollection extends Meteor.Collection
  constructor: (name, manager, @object) ->
    @collection = new Meteor.Collection name, manager
    @object.collection = @
  
  find: (selector, options) ->
    slog "find outer"
    inner_cursor = @collection.find selector, options
    outer_cursor = new StamperCursor (inner_cursor), @object  
    outer_cursor.__proto__.__proto__ = inner_cursor.__proto__
    outer_cursor
  
  findOne: (selector, options) ->
    slog "findone outer"
    result = @collection.findOne selector, options
    if result
      return new @object result
    result
  
  insert: (doc, cb) ->
    slog "insert outer"
    if selector instanceof @object
      selector = selector.raw()
    @collection.insert doc, cb 
  
  update: (selector, modifier, options, cb) ->
    slog "update outer"
    if selector instanceof @object
      selector = selector.id
    @collection.update selector, modifier, options, cb
  
  remove: (selector, cb) ->
    slog "remove outer"
    if selector instanceof @object
      selector = selector.id
    @collection.remove selector, cb  
      
  
  