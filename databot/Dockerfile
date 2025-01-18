# Use Python slim image for smaller size
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Create a Python file with a print statement
RUN echo 'print("Hello from Cloud Build!")' > app.py

# Run the Python script
CMD ["python", "app.py"]
