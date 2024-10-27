# Use an existing image as a base
FROM nginx:latest

# Copy files into the image
COPY ./survey.html /usr/share/nginx/html/

WORKDIR /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Run nginx server
CMD ["nginx", "-g", "daemon off;"]
