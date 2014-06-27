uniqueId = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length
  
@login_then = (newUser, cb) ->
  if newUser
    slog "Logging out to log back in"
    Meteor.logout ->
      loginThen cb
  else
    loginThen cb

loginThen = (cb) ->
  loggingIn = Meteor.loggingIn()
  if !loggingIn
    slog "I wasn't logged(ing) in, let's create a user."
    newuser =
      username: uniqueId()
      password: uniqueId()
    Accounts.createUser _(newuser).clone(), (err, result) ->
      slog 'user created?', err, result, newuser
      if err
        slog 'user creation failed'
        slog err
      else
        Meteor.loginWithPassword
          username: newuser.username
        , newuser.password, (err, result) ->
          if err
            slog "couldn't login: "
            slog err, result
          else
            slog "subscribing to userData", Meteor.user()
            Meteor.subscribe("userData")
            slog "cb is ", cb
            cb()
        slog 'user loginWithPassword attempted', err, result, newuser
  else
    slog "seems I was logged in from the start"
    awaiter = ->
      user =  Meteor.user()
      slog "checking user: it's ", user
      if user and not user.loading
        slog "time to stop. Next line should be 'subscribing to userData'"
        Deps.currentComputation.stop()
        
        Deps.nonreactive ->
          slog "subscribing to old userData"
          Meteor.subscribe("userData")
        cb()
    Deps.autorun awaiter
  
  
    
