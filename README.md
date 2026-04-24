# Skylight Frame

A Ruby gem for interacting with [Skylight](https://www.ourskylight.com) digital photo frames. Provides both a CLI tool and a Ruby library for authentication, listing frames/calendars, and uploading photos.

## Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/jakewilkins/skylight-frame.git
cd skylight-frame
bin/setup
```

## CLI Usage

The CLI is available as `skylight-frame` and supports the following commands:

### Authentication

Store your Skylight account credentials:

```bash
skylight-frame set-password EMAIL PASSWORD
```

Log in (exchanges credentials for an OAuth access token):

```bash
skylight-frame login
```

If credentials are stored, they'll be used automatically. Otherwise you'll be prompted interactively. Tokens are persisted in the macOS Keychain (or an environment variable on other platforms) and refreshed automatically when they expire.

### List Frames

```bash
skylight-frame list-frames
```

### List Calendars

```bash
skylight-frame list-calendars
```

### Upload Photos

Upload one or more photos to a frame or calendar:

```bash
# Upload to a frame
skylight-frame upload-file -f "Living Room" -p photo1.jpg -p photo2.png

# Upload to a calendar
skylight-frame upload-file -c "Family Calendar" -p photo.jpg
```

### Debug Mode

Set the `DEBUG` environment variable for verbose output:

```bash
DEBUG=1 skylight-frame list-frames
```

## Library Usage

You can also use skylight-frame as a Ruby library:

```ruby
require "skylight/client"

# Authenticate (tokens are loaded automatically from the keychain)
client = Skylight::Client.new

# List frames
client.list_frames.each do |frame|
  puts "#{frame.name} (#{frame.id})"
end

# List calendars
client.list_calendars.each do |cal|
  puts "#{cal.name} (#{cal.id})"
end

# Upload photos to a frame by name
client.send_photos_to_frame(
  frame_name: "Living Room",
  photo_paths: ["photo1.jpg", "photo2.jpg"]
)

# Upload photos to a calendar by name
client.send_photos_to_calendar(
  calendar_name: "Family Calendar",
  photo_paths: ["photo.jpg"]
)
```

### OAuth Flow

The `Skylight::Auth` module handles OAuth 2.0 Authorization Code + PKCE authentication:

```ruby
require "skylight/auth"

# Full login flow
token_data = Skylight::Auth.login("user@example.com", "password")
# => { "access_token" => "...", "refresh_token" => "...", "expires_in" => 7200, ... }

# Refresh an existing token
new_tokens = Skylight::Auth.refresh(token_data["refresh_token"])
```

### Credential Storage

Credentials and tokens are managed by `Skylight::Config::AuthorizationProvider`:

```ruby
require "skylight/config"

# Store credentials
Skylight::Config::AuthorizationProvider.update(
  "email" => "user@example.com",
  "password" => "secret"
)

# Read stored data
data = Skylight::Config::AuthorizationProvider.get
# => { "email" => "...", "access_token" => "...", "refresh_token" => "...", ... }
```

On macOS, data is stored in the system Keychain. On other platforms, the `SKYLIGHT_FRAME_AUTH` environment variable is used.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Skylight Frame project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/jakewilkins/skylight-frame/blob/main/CODE_OF_CONDUCT.md).
