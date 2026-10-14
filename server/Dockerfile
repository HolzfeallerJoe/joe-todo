# Sync-Server fuer geteilte Einkaufslisten (Konzept 7.3).
#
# Gebaut wird auf TrueNAS selbst (V11), es gibt kein veroeffentlichtes
# Image. Kontext ist die Wurzel des Repos, weil der Server das Paket
# packages/joe_sync braucht:
#
#   docker build -f server/Dockerfile -t joe-sync .
#
# oder bequemer ueber server/compose.yaml.

FROM dart:3.13 AS build
WORKDIR /src

# Erst nur die pubspecs: solange sich die Abhaengigkeiten nicht aendern,
# bleibt diese Schicht im Cache.
COPY packages/joe_sync/pubspec.yaml packages/joe_sync/
COPY server/pubspec.yaml server/
RUN cd server && dart pub get

COPY packages/joe_sync packages/joe_sync
COPY server server
# Tests laufen mit: ein Image, dessen Tests rot sind, entsteht gar nicht
# erst.
RUN cd server && dart pub get --offline && dart test \
 && dart build cli -t bin/server.dart -o /out

FROM debian:bookworm-slim
# sqlite3 bringt seine Bibliothek im Bundle mit (lib/); aus Debian kommt
# nur die C-Bibliothek.
COPY --from=build /out/bundle/ /app/
COPY --from=build /src/server/web/ /app/web/

# 568 ist der apps-Benutzer von TrueNAS; das Dataset fuer /data sollte ihm
# gehoeren.
RUN mkdir -p /data && chown 568:568 /data
USER 568:568

ENV JOE_PORT=8080 \
    JOE_DB=/data/joe-sync.db \
    JOE_WEB=/app/web
EXPOSE 8080
VOLUME /data

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/app/bin/server", "--health"]

ENTRYPOINT ["/app/bin/server"]
