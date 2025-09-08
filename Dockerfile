# Official Dart image: https://hub.docker.com/_/dart
# Specify the Dart SDK base image version using dart:<version> (ex: dart:2.17)
FROM dart:stable AS build

WORKDIR /app

# Copy Dependencies
COPY packages/walletkit-dart/packages/bip39 ./packages/walletkit-dart/packages/bip39
COPY packages/walletkit-dart ./packages/walletkit-dart

# Install Dependencies
RUN dart pub get -C packages/walletkit-dart/packages/bip39
RUN dart pub get -C packages/walletkit-dart

# Resolve app dependencies.
COPY pubspec.* ./
RUN dart pub get

# Copy app source code
COPY . .

# Install dart_frog CLI and build the application
RUN dart pub global activate dart_frog_cli
RUN dart pub global run dart_frog_cli:dart_frog build

# Ensure packages are still up-to-date if anything has changed
RUN dart pub get --offline -C build
RUN dart compile exe build/bin/server.dart -o bin/server

# Build minimal serving image from AOT-compiled `/server` and required system
# libraries and configuration files stored in `/runtime/` from the build stage.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

# Start server.
CMD ["/app/bin/server"]