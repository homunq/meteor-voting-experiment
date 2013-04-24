
deparam = (params, coerce) -> #from jquery-bbq
  obj = {}
  coerce_types =
    true: not 0
    false: not 1
    null: null

  
  # Iterate over all name=value pairs.
  $.each params.replace(/\+/g, " ").split("&"), (j, v) ->
    param = v.split("=")
    key = decodeURIComponent(param[0])
    val = undefined
    cur = obj
    i = 0
    
    # If key is more complex than 'foo', like 'a[]' or 'a[b][c]', split it
    # into its component parts.
    keys = key.split("][")
    keys_last = keys.length - 1
    
    # If the first keys part contains [ and the last ends with ], then []
    # are correctly balanced.
    if /\[/.test(keys[0]) and /\]$/.test(keys[keys_last])
      
      # Remove the trailing ] from the last keys part.
      keys[keys_last] = keys[keys_last].replace(/\]$/, "")
      
      # Split first keys part into two parts on the [ and add them back onto
      # the beginning of the keys array.
      keys = keys.shift().split("[").concat(keys)
      keys_last = keys.length - 1
    else
      
      # Basic 'foo' style key.
      keys_last = 0
    
    # Are we dealing with a name=value pair, or just a name?
    if param.length is 2
      val = decodeURIComponent(param[1])
      
      # Coerce values.
      # number
      # undefined
      # true, false, null
      val = (if val and not isNaN(val) then +val else (if val is "undefined" then `undefined` else (if coerce_types[val] isnt `undefined` then coerce_types[val] else val)))  if coerce # string
      if keys_last
        
        # Complex key, build deep object structure based on a few rules:
        # * The 'cur' pointer starts at the object top-level.
        # * [] = array push (n is set to array length), [n] = array if n is 
        #   numeric, otherwise object.
        # * If at the last keys part, set the value.
        # * For each keys part, if the current level is undefined create an
        #   object or array based on the type of the next keys part.
        # * Move the 'cur' pointer to the next level.
        # * Rinse & repeat.
        while i <= keys_last
          key = (if keys[i] is "" then cur.length else keys[i])
          cur = cur[key] = (if i < keys_last then cur[key] or ((if keys[i + 1] and isNaN(keys[i + 1]) then {} else [])) else val)
          i++
      else
        
        # Simple key, even simpler rules, since only scalars and shallow
        # arrays are allowed.
        if $.isArray(obj[key])
          
          # val is already an array, so push on the next value.
          obj[key].push val
        else if obj[key] isnt `undefined`
          
          # val isn't an array, but since a second value has been specified,
          # convert val into an array.
          obj[key] = [obj[key], val]
        else
          
          # val is a scalar.
          obj[key] = val
    
    # No value was defined, so set something meaningful.
    else obj[key] = (if coerce then `undefined` else "")  if key

  obj
    
class @MyRouter extends ReactiveRouter
  routes:
    '?:params': 'watchElection'
    'election/:eid': 'inElection'
    'elections/clear/all': 'clearAll'
    'elections/makeOne/:scenario/:method': 'makeElection'
    'elections/makeOne/:scenario/:method/:delay': 'makeElection'
    'elections/makeOne/:scenario/:method/:delay/:roundBackTo': 'makeElection'
    'admin/elections/:password/:fromVersion': 'electionsReport'
    'admin/payments/:password/:eid': 'payments'
    
  watchElection: (params) ->
    console.log 'watch'
    console.log Backbone.history.getFragment()
    if params
      params = deparam params
    login_then =>
      user = new User Meteor.user()
      user.setParams params
      console.log "About to watchMain", user._id
      Election.watchMain (error, result) =>
        console.log "watchmain e=", error
        console.log "watchmain r=", result
        
        @goto 'loggedIn'
        #console.log 'qwpr' + JSON.stringify Meteor.user()
    #@navigate 'election/new',
    #  trigger: true

  inElection: (eid) =>
    console.log "route: election"
    login_then =>
      console.log "route: election; logged in"
      Election.watch eid, =>
        @goto 'loggedIn' #use that template
        
  clearAll: ->
    console.log "clear all"
    Election.clearAll()
    
  goto: (where) ->
    console.log "going to", where
    if where is 'loggedIn'
      console.log "yes, going to", where, $('#loading').hide()
      $('#loading').hide()
    super arguments...
    
  makeElection: (scenario, method, delay=100, roundBackTo=-1) ->
    console.log "makeElection", scenario, method, delay, roundBackTo
    delay = parseInt delay
    roundBackTo = parseInt roundBackTo
    Election.make
      scenario: scenario
      method: method
    , true, delay, roundBackTo, (result, error) =>
      Session.set "madeEid", result
      @goto 'madeElection' #use that template
      
    @goto 'madeElection' #use that template
    Meteor.logout()
    
  electionsReport: (password, fromVersion) ->
    Session.set 'password', password
    Session.set 'fromVersion', (parseFloat fromVersion) or 0.93
    console.log "going to elections report..."
    @goto 'electionsReport'
    
  payments: (password, eid) ->
    console.log "payments"
    if eid is "x"
      latestElection = Elections.findOne {},
        sort: [["sTimes.0", "desc"]]
      eid = latestElection._id
    Outcomes.adminSubscribe(password)
    Session.set 'adminEid', eid
    @goto 'payments'
          

global = @

router = global.Router = new MyRouter()

if Meteor.isClient
  Session.set 'router', true

Meteor.startup ->
  console.log "I should maybe $('#loading').hide()"
  old_eid = null
  console.log "startup router"
  Backbone.history.start
     pushState: true
  #Meteor.autosubscribe ->
  #  console.log "should I??? $('#loading').hide()", router?.current_page()
  #  if ((Session.get 'router') and router?.current_page()) is 'loggedIn'
  #    console.log "$('#loading').hide()"
  #    $('#loading').hide()
  #  else
  #    console.log "NOT     $('#loading').hide()", (Session.get 'router'), router?.current_page()