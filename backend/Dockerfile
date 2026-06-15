FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY TrafficLightMvp.csproj ./
RUN dotnet restore

COPY . ./
RUN dotnet publish TrafficLightMvp.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish ./
COPY schema.sql ./schema.sql

ENV ASPNETCORE_ENVIRONMENT=Production
ENV PORT=8000
EXPOSE 8000

ENTRYPOINT ["dotnet", "TrafficLightMvp.dll"]
