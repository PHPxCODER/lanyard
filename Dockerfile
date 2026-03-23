FROM elixir:1.19-alpine AS build

RUN apk add git

ENV MIX_ENV=prod

WORKDIR /app

# Install hex and rebar in a separate layer so they are cached independently
RUN mix local.hex --force && mix local.rebar --force

# Copy only dependency manifests first to cache deps layer
COPY mix.exs mix.lock ./
RUN mix deps.get

# Copy the rest of the source and compile
COPY . .
RUN mix compile && mix release

FROM elixir:1.19-alpine

RUN apk add redis tini

COPY --from=build /app/_build/prod/rel/lanyard /opt/lanyard

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD [ "/opt/lanyard/bin/lanyard", "start" ]
