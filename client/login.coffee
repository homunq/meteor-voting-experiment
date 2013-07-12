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
  user = Meteor.user()
  if !user
    slog "I wasn't logged in, let's create a user."
    newuser =
      username: uniqueId()
      password: uniqueId()
    Accounts.createUser _(newuser).clone(), (err, result) ->
      slog 'user created?', err, result, newuser.username
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
            Meteor.subscribe("userData", Meteor.user()._id)
            cb()
        slog 'user loginWithPassword attempted', err, result, newuser.username
  else 
    slog "seems I was logged in from the start"
    Meteor.deps.await ->
      user =  Meteor.user()
      slog "checking user: it's ", user
      user and not user.loading
    , ->
      slog "subscribing to userData"
      Meteor.subscribe("userData", Meteor.user()._id)
      cb()
    , true #once only
    
