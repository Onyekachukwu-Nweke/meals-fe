# Build stage
FROM node:22-alpine AS builder

WORKDIR /app

# Install dependencies first for better Docker caching
COPY package.json ./
RUN npm install

# Copy source code and build
COPY . .
RUN npm run build


# Production stage
FROM nginx:1.27-alpine

# Remove the default Nginx website
RUN rm -rf /usr/share/nginx/html/*

COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the Vite build output
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
