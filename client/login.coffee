uniqueId = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length
  
@login_then = (cb) ->
  user = Meteor.user()
  console.log 'user'
  console.log user
  if !user
    newuser =
      username: uniqueId()
      password: uniqueId()
    Meteor.createUser newuser, {}, (err) ->
      if err
        console.log 'user creation failed'
      else
        Meteor.loginWithPassword
          username: newuser.username
        , newuser.password, (err) ->
          if err
            console.log "couldn't login: " + err
            console.log err
          else
            cb()
  else 
    console.log 'await'
    Meteor.deps.await ->
      console.log 'user awaiting'
      console.log Meteor.user()
      user =  Meteor.user()
      user and not user.loading
    , ->
      console.log 'user awaited'
      console.log Meteor.user()
    
      cb()
    , true #once only
    
