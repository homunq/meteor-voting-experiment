uniqueId = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length
  
@login_then = (cb) ->
  user = Meteor.user()
  if !user
    newuser =
      username: uniqueId()
      password: uniqueId()
    Meteor.createUser _(newuser).clone(), {}, (err) ->
      if err
        console.log 'user creation failed'
        console.log err
      else
        Meteor.loginWithPassword
          username: newuser.username
        , newuser.password, (err) ->
          if err
            console.log "couldn't login: "
            console.log err
          else
            cb()
  else 
    Meteor.deps.await ->
      user =  Meteor.user()
      user and not user.loading
    , ->
      console.log Meteor.user()
    
      cb()
    , true #once only
    
