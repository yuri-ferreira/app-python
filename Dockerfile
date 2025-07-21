FROM python:alpine3.22

WORKDIR /app

RUN pip install "fastapi" uvicorn

COPY main.py .

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]