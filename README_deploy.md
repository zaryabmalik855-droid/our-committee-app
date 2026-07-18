# Deployment Guide: Our Committee AI Backend

This guide outlines how to deploy the FastAPI AI Backend using Hugging Face Spaces or Render.

## 1. Deploying to Hugging Face Spaces (Free)

Hugging Face Spaces provides an excellent free tier for hosting containerized backend applications (Docker Spaces).

1. Go to [Hugging Face Spaces](https://huggingface.co/spaces) and create a new Space.
2. Select **Docker** as the Space SDK and choose the **Blank** template.
3. Upload the contents of the `backend/` directory to the Space.
4. Go to Space **Settings** -> **Variables and secrets**.
5. Add your API Keys as **Secrets**:
   - `GEMINI_API_KEY`: Your Google Gemini API Key.
   - `OPENAI_API_KEY`: Your OpenAI API Key (optional, if using GPT-4o).
6. Set **Variables** (optional):
   - `LLM_PROVIDER`: `gemini` (default) or `openai`
7. The Space will build and deploy. Once "Running", click on the "App" view, or click the three dots -> "Embed this Space" to get the direct URL (e.g., `https://username-our-committee-ai.hf.space`).
8. Update the `AI_BACKEND_URL` in `lib/services/ai_service.dart` with your Hugging Face Space URL.

## 2. Deploying to Render (Free Tier Available)

Render is a popular platform for deploying web services.

1. Push your code to a GitHub repository.
2. Sign up on [Render](https://render.com) and create a new **Web Service**.
3. Connect your GitHub repository.
4. Set the following configuration:
   - **Environment**: Docker
   - **Build Context Directory**: `./backend`
   - **Dockerfile Path**: `./backend/Dockerfile`
5. Add your Environment Variables:
   - `GEMINI_API_KEY`
   - `LLM_PROVIDER`
6. Click **Create Web Service**. Render will build the Docker container and deploy it.
7. Update the `AI_BACKEND_URL` in `lib/services/ai_service.dart` with your `.onrender.com` URL.

## 3. Local Development with Docker Compose

To test everything locally:

```bash
cd project/
docker-compose up --build
```

- Backend API: `http://localhost:8000`
- Streamlit Demo: `http://localhost:8501`

Update the `AI_BACKEND_URL` in the Flutter app to point to your local machine (`http://10.0.2.2:8000` for Android Emulator, or `http://localhost:8000` for iOS/Web).
