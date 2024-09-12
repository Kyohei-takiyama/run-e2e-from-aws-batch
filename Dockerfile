FROM mcr.microsoft.com/playwright:v1.47.0-focal

WORKDIR /app

COPY . .

RUN npm install

# CMD ["npm", "run", "test"]