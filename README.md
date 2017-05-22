
# Swift client for Pilosa

> **NOTE** This is a work in progress

Swift client for [Pilosa](http://www.pilosa.com), a high performance distributed bitmap index.

## Install
For now, you need to manually download and link the framework in your project.

### Supported Platforms
- macOS

## Usage

### Quick Overview
Assuming Pilosa server is running at localhost:10101 (the default):

```
import Pilosa

// Create the default client
// You can also specify the Pilosa URI or Cluster
// to use
let client = Client()

// Attempt creating index and frame references
// These calls can fail in case the naming 
// conventions are not satisfied
let index = try! Index(name: "repos", columnLabel: "repo_id")
let frame = try! index.frame(name: "language")

// Ensure our index and frame exists
client.ensure(index)
client.ensure(frame)

// batch a set of SetBit operations
// and send to the server
client.query(
	index.batch(
        frame.setBit(1,1),
        frame.setBit(1,2),
	    frame.setBit(2,3)
	)
)

// run a PQL query
let response = client.query(frame[2].union(frame[3]).count())
// frame.bitmap(2) and frame[2] are equivalent

switch response {
	case .success(let results):
		// work with results
	case .failure(let error): 
		print(error)
}

```
