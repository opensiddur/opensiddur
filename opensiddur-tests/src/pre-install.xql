xquery version "3.0";
(:~ pre-install script for tests :)

declare function local:create-user(
    $user as xs:string
    ) {
    let $exists := sm:user-exists($user)
    where not($exists)
    return sm:create-account($user, $user, 'everyone')
};

util:log-system-out("Adding test users..."),
for $user in ('testuser', 'testuser2')
return local:create-user($user)
util:log-system-out("Done.")

