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
return
    try {
        util:log-system-out("before: " || $user),
        local:create-user($user),
        util:log-system-out("after: " || $user)
    }
    catch * {
        util:log-system-out(concat("Could not create user ", $user,
                $err:module, ":", $err:line-number, ":",
                $err:column-number, ","[$err:code], $err:code, ":"[$err:value], $err:value, ": "[$err:description],
                $err:description,
                ";"
        ))
    },
util:log-system-out("Done.")


