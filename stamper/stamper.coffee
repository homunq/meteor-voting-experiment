class Field #lower case because i
  constructor: (@default, @validator) ->
      
  invalid: (val) ->
    if @validator
      return !@validator val
    false
    
#Don't worry about stomping this variable inside a function, you'll never need it out of a class declaration.
field = -> #just some sugar to save typing "new". 
  new Field arguments...
  
class Instance
  constructor: (props) ->
    if @_fields
      for pname, prop of props
        if not @_fields[pname]?
          throw new Error "Invalid property name: #{ pname } (#{ prop }) when constructing a #{ @constructor.name }"
        else if @_fields[pname].invalid
          throw new Error "Invalid property val: #{ pname } (#{ prop }) when constructing a #{ @constructor.name }"
      for name, f of @_fields
        if not props[fname]?
          props[fname] = f.default
    _.extend this, props
  
  @fields: (_fields) ->
    @_fields = {}
    
    for fname, f of _fields
      if not (f instanceof Field)
        f = field f
      @_fields[fname] = f
       
  @static: (fn) -> #for use inside @register
    fn.static = true
    fn
    
  @register: (methods) ->
    servermethods = {}
    for mname, method of methods
      do -> #closure so that client-side method can sneak a reference to instance into the generic
            #Meteor.methods stub.
            #This technique isn't threadsafe but that's OK, no threads on client.
        cur_instance = undefined
        smname = @constructor.name + "_" + mname
        if !method.static
          servermethods[smname] = (id, args...) =>
            if meteor.is_server
              cur_instance = @collection.findOne
                _id: id
            if !cur_instance
              throw Meteor.error 404, "No such object on #{ 'server' if Meteor.isServer else 'client' }"
            cur_instance[smname] args...
        else
          servermethods[smname] = (args...) =>
            @[smname] args...
            
        if Meteor.isClient 
          @[mname] = (args...) ->
            cur_instance = @
            if method.static
              Meteor.call smname, args...
            else
              Meteor.call smname, @_id, args...
        else
          @[mname] = method
        @[smname] = method
    Meteor.methods servermethods
    
  raw: ->
    if @_fields
      return _.pick(@, _.keys @_fields)
    @
     
  save: (cb) ->
    if @_id
      @collection.update
        _id: @_id
      , @raw(), cb
    else
      @collection.insert @, cb
          
  remove: (cb) ->
    @collection.remove
      _id: @_id
    , cb
    
    
  