FROM postgres:15-alpine

# Install additional extensions
RUN apk add --no-cache postgresql-contrib

# Create initialization script
COPY init.sql /docker-entrypoint-initdb.d/

# Environment variables
ENV POSTGRES_DB=referral_points
ENV POSTGRES_USER=referral_user
ENV POSTGRES_PASSWORD=referral_password

# Expose port
EXPOSE 5432 