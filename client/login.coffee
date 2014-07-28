global = @

uniqueId = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length
  
@login_then = (newUser, cb) ->
  if newUser
    debug "Logging out to log back in"
    Meteor.logout ->
      loginThen cb
  else
    loginThen cb

loginThen = (cb) ->
  loggingIn = Meteor.loggingIn()
  if !loggingIn
    debug "I wasn't logged(ing) in, let's create a user."
    newuser =
      username: uniqueId()
      password: uniqueId()
    Accounts.createUser _(newuser).clone(), (err, result) ->
      debug 'user created?', err, result, newuser
      if err
        debug 'user creation failed'
        debug err
      else
        Meteor.loginWithPassword
          username: newuser.username
        , newuser.password, (err, result) ->
          if err
            debug "couldn't login: "
            debug err, result
          else
            debug "subscribing to userData", Meteor.user()
            Meteor.subscribe("userData")
            debug "cb is ", cb
            cb()
        debug 'user loginWithPassword attempted', err, result, newuser
  else
    debug "seems I was logged in from the start"
    awaiter = ->
      user =  Meteor.user()
      debug "checking user: it's ", user
      if user and not user.loading
        debug "time to stop. Next line should be 'subscribing to userData'"
        Deps.currentComputation.stop()
        
        Deps.nonreactive ->
          
          debug "subscribing to old userData"
          global.USER_INCOMPLETE = on
          Meteor.subscribe "userData", ->
            cb()
    Deps.autorun awaiter
  
  
    
