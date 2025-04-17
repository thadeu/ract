<div href="#" style="text-align: center; width: 50%; margin: 0 auto;">
  <img src="./images/ract-no-bg.png" alt="Ract Logo"  style="position: relative; margin-top: -50px; z-index: 1; display: flex; align-items: center; justify-content: center; text-align: center; mix-blend-mode: overlay;">
</div>

<h1 style="z-index: 999; text-align: center;">Ract</h1>

Ract is a lightweight Promise implementation for Ruby, simliar color promises in JavaScript providing a clean and intuitive way to handle asynchronous operations.

> [!NOTE] 
> This is dont use Ractor, we just Threads to handle async operations
> Enjoy with us!

[![CI](https://github.com/thadeu/ract/workflows/ci/badge.svg)](https://github.com/thadeu/ract/actions?workflow=ci)

# Features

- Thread-safe
- Similar to JavaScript Promises
- Clean and intuitive API
- Easy to use

## Installation

Install the gem and add to the application's Gemfile by executing:

```ruby
gem 'ract'
```

And then execute:

```bash
$ bundle install
```

or using add

```bash
$ bundle add ract
```

Or install it yourself as:

```bash
$ gem install ract
```

## Usage

```ruby
require 'ract'
```

### Basic Usage

Create a new promise with a block that will be executed asynchronously:

```ruby
# Create a promise that resolves with a value
promise = Ract.new { 42 } # or just Ract { 42 }

# Create a promise that might reject with an error
promise = Ract.new do
  if success_condition
    "Success result"
  else
    raise "Something went wrong"
  end
end
```

### Handling Promise Resolution

Use `.then` to handle successful resolution:

```ruby
promise = Ract.new { 42 }

promise.then do |value|
  puts "The answer is #{value}"
end
```

### Error Handling

Use `.rescue` (or its alias `.catch`) to handle rejections:

```ruby
promise = Ract.new { raise "Something went wrong" }

promise
  .then { |value| puts "This won't be called" }
  .rescue { |error| puts "Error: #{error.message}" }
```

### Chaining Promises

Promises can be chained for sequential asynchronous operations:

```ruby
Ract.new { fetch_user(user_id) }
  .then { |user| fetch_posts(user.id) }
  .and_then { |posts| render_posts(posts) }
  .rescue { |error| handle_error(error) }
  .catch { |error| handle_error(error) }
```

### Waiting for Resolution

If you need to wait for a promise to resolve, use `.await`:

```ruby
promise = Ract.new { time_consuming_operation }
result = promise.await  # Blocks until the promise resolves
```

### Creating Pre-resolved Promises

Create already resolved or rejected promises:

```ruby
# Already resolved promise
promise = Ract.resolve(42)

# Already rejected promise
promise = Ract.reject("Something went wrong")
```

### Combining Multiple Promises

Wait for multiple promises to complete:

```ruby
# Wait for all promises to resolve (will raise an error if any promise rejects)
promises = [Ract.new { task1 }, Ract.new { task2 }]
combined = Ract.all(promises)

# Wait for all promises to resolve (will not raise errors, returns results with status)
combined = Ract.all(promises, raise_on_error: false)

# Get results when all are settled (resolved or rejected)
results = Ract.all_settled(promises)
```

### Using block

You can use a block to receive result

```ruby
tasks = [ ract { "mylogs" } ]

Ract.take(tasks) { p it }
# ["mylogs"]
```

This update properly explains that:

1. By default, `Ract.all` will raise an error if any of the promises are rejected
2. You can set `raise_on_error: false` to get all results regardless of whether they resolved or rejected
3. Alternatively, you can use `Ract.all_settled` to get results for all promises whether they resolved or rejected

### Immediate Execution

If you need to execute a block immediately with the current value, regardless of the promise state:

```ruby
promise = Ract.new { 42 }
promise.then { |value| puts "Current value: #{value}" }
```

### Async/Await Pattern

Ract supports an async/await pattern similar to JavaScript:

```ruby
# Define an async method
async def fetch_data
  user = fetch_user(user_id)
  posts = fetch_posts(user.id)
  comments = fetch_comments(posts.first.id)

  return { user: user, posts: posts, comments: comments }
end

# Use the async method
result = fetch_data.await
```

### Examples using many callable promises

```ruby
class Dynamo
  async def self.get_item(table, key)
    { Item: {} }
  end
end

tasks = [
  Dynamo.get_item_async('users', 1),
  Dynamo.get_item_async('posts', 1),
  Dynamo.get_item_async('comments', 1)
]

result_all = Ract.all(tasks, raise_on_error: false) 
result_taken = Ract.take(tasks, raise_on_error: false) 

p result_all
# [{ Item: {} }, { Item: {} }, { Item: {} }]

p result_taken
# [{ Item: {} }, { Item: {} }, { Item: {} }]
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/thadeu/ract.

## License

The gem is available as open source under the terms of the MIT License.
