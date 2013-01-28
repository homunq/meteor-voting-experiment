uniqueId = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length
  
@login_then = (cb) ->
  user = Meteor.user()
  if !user
    console.log "I wasn't logged in, let's create a user."
    newuser =
      username: uniqueId()
      password: uniqueId()
    Accounts.createUser _(newuser).clone(), (err, result) ->
      console.log 'user created?', err, result
      if err
        console.log 'user creation failed'
        console.log err
      else
        Meteor.loginWithPassword
          username: newuser.username
        , newuser.password, (err, result) ->
          if err
            console.log "couldn't login: "
            console.log err, result
          else
            console.log "subscribing to userData"
            Meteor.subscribe("userData", Meteor.user()._id)
            cb()
  else 
    console.log "seems I was logged in from the start"
    Meteor.deps.await ->
      user =  Meteor.user()
      console.log "checking user: it's ", user
      user and not user.loading
    , ->
      console.log "subscribing to userData"
      Meteor.subscribe("userData", Meteor.user()._id)
      cb()
    , true #once only
    
