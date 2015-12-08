# Promise.swift

Promise.swift - A Promise implementation written in Swift

===

# Usage
``` swift
Promise.resolve(10)
       .then(increment)
       .then(doubleUp)
       .`catch` { _ in print("error!") }
       .then { v in
           print(p) // 22
       }
```

# Licence
MIT

# Author
[@yashigani](https://github.con/yashigani)

