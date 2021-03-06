
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

global = @
   
class @MyRouter extends ReactiveRouter
  routes:
    '?:params': 'watchElection'
    ':newUser?:params': 'watchElection2'
    'election/:eid': 'inElection'
    'elections/clear/all': 'clearAll'
    'elections/make/': 'electionMaker'
    'elections/makeOne/:scenario/:method': 'makeElection'
    'elections/makeOne/:scenario/:method/:delay': 'makeElection'
    'elections/makeOne/:scenario/:method/:delay/:roundBackTo': 'makeElection'
    'admin/elections/:password/:version': 'electionsReport'
    'admin/payments/:password/:version': 'payments'
    'admin/answers/:password/:version': 'adminAnswers'
    'admin/voters/:password/:version': 'adminVoters'
    'admin/votes/:password/:version': 'adminVotes'
    
  electionMaker: () ->
    debug 'maker loaded'
    @goto 'electionMaker'
  
  watchElection2: (newUser, params) ->
    @watchElection params, newUser
    
  watchElection: (params, newUser) ->
    #debug 'watch'
    debug Backbone.history.getFragment()
    if params
      xparams = deparam params
    debug "watchElection params", params
    for k, v of xparams
      debug "one param", k, v
    if xparams?.debugNum
      global.debugNum = parseInt xparams.debugNum
    debug "gonna login_then 1", newUser
    login_then newUser, =>
      debug "did login_then 1"
      user = Meteor.user()
      if user
        user = new MtUser Meteor.user()
        user.setParams xparams
        if not user.eid
          #debug "About to watchMain", user._id
          Election.watchMain (error, result) =>
            #debug "watchmain e=", error
            #debug "watchmain r=", result
          
            @goto 'loggedIn'
        else
          @goto 'loggedIn'
      else
        Session.set 'error', "Login failed; please reload"
        @goto 'loggedIn'
        #debug 'qwpr' + JSON.stringify Meteor.user()
    #@navigate 'election/new',
    #  trigger: true

  inElection: (eid) =>
    #debug "route: election"
    debug "gonna login_then 2"
    login_then =>
      debug "did login_then 1"
      #debug "route: election; logged in"
      Election.watch eid, =>
        @goto 'loggedIn' #use that template
        
  clearAll: ->
    debug "clear all"
    Election.clearAll()
    
  goto: (where) ->
    #debug "going to", where
    if where is 'loggedIn'
      #debug "yes, going to", where, $('#loading').hide()
      $('#loading').hide()
    super arguments...
    
  makeElection: (scenario, method, delay=100, roundBackTo=-1) ->
    debug "makeElection", scenario, method, delay, roundBackTo
    delay = parseInt delay
    #debug "makeElection q", scenario, method, delay, roundBackTo
    roundBackTo = parseInt roundBackTo
    Election.make
      scenario: scenario
      method: method
    , true, delay, roundBackTo, (result, error) =>
      Session.set "madeEid", result
      @goto 'madeElection' #use that template
      
    #debug "makeElection 3", scenario, method, delay, roundBackTo
    @goto 'madeElection' #use that template
    Meteor.logout()
    
  electionsReport: (password, version) ->
    debug "electionsReport"
    Session.set 'password', password
    @vToQ version
    Elections.adminSubscribe password
    Outcomes.adminSubscribe password
    Votes.adminSubscribe password
    #debug "going to elections report..."
    @goto 'electionsReport'
    
  vToQ: (version, extra) ->
    query = Session.get 'QUERY'
    if not query
      if version is "latestElection"
        latestElection = Elections.findOne {},
          sort: [["sTimes.0", "desc"]]
        query = 
          eid: [latestElection._id] #eid, not election; used on users collection
      else if version is "current"
        query = 
          version: VERSION
          
      else
        query = 
          version: parseInt version
      
      if extra
        _.extend query, extra
      Session.set 'QUERY', query
          
  payments: (password, version) ->
    #debug "payments"
    Session.set 'password', password
    Elections.adminSubscribe password
    Outcomes.adminSubscribe password
    Meteor.users.adminSubscribe password
    StepRecords.adminSubscribe password
    Votes.adminSubscribe password
    @vToQ version,
      faction: 
        $in:[0,1,2]
    @goto 'payments'
    
  adminAnswers: (password, version) ->
    #debug "payments"
    Session.set 'password', password
    Meteor.users.adminSubscribe password
    SurveyResponses.adminSubscribe password
    Outcomes.adminSubscribe password
    Votes.adminSubscribe password
    @vToQ version
    @goto 'answers'
    
  adminVoters: (password, version) ->
    Session.set 'password', password
    Elections.adminSubscribe password
    Votes.adminSubscribe password
    @vToQ version
    @goto 'adminVoters'
    
  adminVotes: (password, version) ->
    Session.set 'password', password
    Elections.adminSubscribe password
    Votes.adminSubscribe password
    Outcomes.adminSubscribe password
    StepRecords.adminSubscribe password
    Meteor.users.adminSubscribe password
    @vToQ version
    @goto 'adminVotes'
          

ROUTER = global.ROUTER = new MyRouter()

if Meteor.isClient
  Session.set 'router', true

Meteor.startup ->
  #debug "I should maybe $('#loading').hide()"
  old_eid = null
  debug "startup router"
  Backbone.history.start
     pushState: true
  #Meteor.autosubscribe ->
  #  debug "should I??? $('#loading').hide()", router?.current_page()
  #  if ((Session.get 'router') and router?.current_page()) is 'loggedIn'
  #    debug "$('#loading').hide()"
  #    $('#loading').hide()
  #  else
  #    debug "NOT     $('#loading').hide()", (Session.get 'router'), router?.current_page()