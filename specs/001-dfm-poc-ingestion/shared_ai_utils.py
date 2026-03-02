"""
shared_ai_utils.py
Shared AI utilities for DFM PoC Phase 9.

Supports both GitHub Models API (default, low-cost) and Azure OpenAI (optional, production).
All AI notebooks use this module's interface unchanged.
"""

import json
import os
from typing import Optional, Dict, Any, List
import requests


class AIBackend:
    """Base class for AI backends."""
    pass


class GitHubModelsBackend(AIBackend):
    """GitHub Models API backend (low-cost, pay-as-you-go)."""
    
    def __init__(self, github_token: str, endpoint: str = "https://models.githubnext.com"):
        """
        Initialize GitHub Models client.
        
        Args:
            github_token: GitHub Personal Access Token with API scope.
            endpoint: GitHub Models endpoint (default: https://models.githubnext.com).
        """
        self.token = github_token
        self.endpoint = endpoint
        self.headers = {
            "Authorization": f"Bearer {github_token}",
            "Content-Type": "application/json"
        }
    
    def chat_completion(
        self, 
        model: str, 
        messages: List[Dict[str, str]], 
        temperature: float = 0.7, 
        max_tokens: int = 1000
    ) -> str:
        """
        Call GitHub Models text completion endpoint.
        
        Args:
            model: Model name (gpt-4o, gpt-4o-mini, o1, etc.)
            messages: List of message dicts with 'role' and 'content'.
            temperature: Sampling temperature (0.0-2.0).
            max_tokens: Max tokens in response.
        
        Returns:
            Completion text.
        """
        payload = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens
        }
        
        response = requests.post(
            f"{self.endpoint}/chat/completions",
            headers=self.headers,
            json=payload,
            timeout=30
        )
        response.raise_for_status()
        
        data = response.json()
        return data["choices"][0]["message"]["content"]
    
    def embedding(self, model: str, text: str) -> List[float]:
        """
        Generate embedding via GitHub Models.
        
        Args:
            model: Model name (text-embedding-3-small, etc.)
            text: Text to embed.
        
        Returns:
            Embedding vector.
        """
        payload = {
            "model": model,
            "input": text
        }
        
        response = requests.post(
            f"{self.endpoint}/embeddings",
            headers=self.headers,
            json=payload,
            timeout=30
        )
        response.raise_for_status()
        
        data = response.json()
        return data["data"][0]["embedding"]


class AzureOpenAIBackend(AIBackend):
    """Azure OpenAI backend (production-grade, higher throughput)."""
    
    def __init__(self, endpoint: str, api_key: str, api_version: str = "2024-08-01-preview"):
        """
        Initialize Azure OpenAI client.
        
        Args:
            endpoint: Azure OpenAI endpoint (https://<resource>.openai.azure.com/).
            api_key: Azure OpenAI API key.
            api_version: API version.
        """
        from azure.ai.openai import AzureOpenAI
        
        self.client = AzureOpenAI(
            api_key=api_key,
            api_version=api_version,
            azure_endpoint=endpoint
        )
        self.api_version = api_version
    
    def chat_completion(
        self, 
        model: str, 
        messages: List[Dict[str, str]], 
        temperature: float = 0.7, 
        max_tokens: int = 1000
    ) -> str:
        """
        Call Azure OpenAI chat completion.
        
        Args:
            model: Deployment name (gpt-4o, gpt-4o-mini, etc.)
            messages: List of message dicts.
            temperature: Sampling temperature.
            max_tokens: Max tokens in response.
        
        Returns:
            Completion text.
        """
        response = self.client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens
        )
        return response.choices[0].message.content
    
    def embedding(self, model: str, text: str) -> List[float]:
        """
        Generate embedding via Azure OpenAI.
        
        Args:
            model: Deployment name.
            text: Text to embed.
        
        Returns:
            Embedding vector.
        """
        response = self.client.embeddings.create(
            model=model,
            input=text
        )
        return response.data[0].embedding


class AIClient:
    """Unified AI client interface for all notebooks."""
    
    def __init__(self, config: Dict[str, Any]):
        """
        Initialize AI client from config.
        
        Args:
            config: Dict with 'use_github_models' (bool) and backend-specific fields.
                    GitHub Models: 'github_token', 'github_models_endpoint' (optional).
                    Azure OpenAI: 'api_key', 'endpoint', 'api_version' (optional).
        """
        self.use_github_models = config.get("use_github_models", True)
        
        if self.use_github_models:
            github_token = config.get("github_token")
            if not github_token:
                raise ValueError("github_token required in config for GitHub Models backend.")
            endpoint = config.get("github_models_endpoint", "https://models.githubnext.com")
            self.backend = GitHubModelsBackend(github_token, endpoint)
        else:
            api_key = config.get("api_key")
            endpoint = config.get("endpoint")
            if not api_key or not endpoint:
                raise ValueError("api_key and endpoint required in config for Azure OpenAI backend.")
            api_version = config.get("api_version", "2024-08-01-preview")
            self.backend = AzureOpenAIBackend(endpoint, api_key, api_version)
        
        self.config = config
    
    def schema_map(self, text: str, max_tokens: Optional[int] = None) -> str:
        """Map text to target schema (SC-13, fuzzy resolution)."""
        max_tokens = max_tokens or self.config.get("schema_mapper_max_tokens", 1000)
        temperature = self.config.get("schema_mapper_temperature", 0.0)
        model = self.config.get("schema_mapper_deployment", "gpt-4o")
        
        messages = [
            {
                "role": "system",
                "content": "You are a financial data schema mapping expert. Map the provided text to the target schema."
            },
            {"role": "user", "content": text}
        ]
        
        return self.backend.chat_completion(model, messages, temperature, max_tokens)
    
    def detect_anomaly(self, data: str, max_tokens: Optional[int] = None) -> str:
        """Detect anomalies in financial data (SC-14)."""
        max_tokens = max_tokens or self.config.get("anomaly_detector_max_tokens", 1500)
        temperature = self.config.get("anomaly_detector_temperature", 0.2)
        model = self.config.get("anomaly_detector_deployment", "gpt-4o")
        
        messages = [
            {
                "role": "system",
                "content": "You are a financial analyst. Detect anomalies in the provided holdings data."
            },
            {"role": "user", "content": data}
        ]
        
        return self.backend.chat_completion(model, messages, temperature, max_tokens)
    
    def triage_exception(self, exception_data: str, max_tokens: Optional[int] = None) -> str:
        """Triage validation exceptions (SC-15)."""
        max_tokens = max_tokens or self.config.get("triage_max_tokens", 2000)
        temperature = self.config.get("triage_temperature", 0.0)
        model = self.config.get("triage_deployment", "gpt-4o-mini")
        
        messages = [
            {
                "role": "system",
                "content": "You are a data quality expert. Classify the exception and suggest root causes."
            },
            {"role": "user", "content": exception_data}
        ]
        
        return self.backend.chat_completion(model, messages, temperature, max_tokens)
    
    def generate_narrative(self, summary_data: str, max_tokens: Optional[int] = None) -> str:
        """Generate narrative summary (SC-16)."""
        max_tokens = max_tokens or self.config.get("narrative_max_tokens", 800)
        temperature = self.config.get("narrative_temperature", 0.4)
        model = self.config.get("narrative_deployment", "gpt-4o")
        
        messages = [
            {
                "role": "system",
                "content": "You are a financial report writer. Generate a concise narrative summary."
            },
            {"role": "user", "content": summary_data}
        ]
        
        return self.backend.chat_completion(model, messages, temperature, max_tokens)
    
    def embed_text(self, text: str) -> List[float]:
        """Generate embedding (for schema similarity, etc.)."""
        model = self.config.get("embedding_deployment", "text-embedding-3-small")
        return self.backend.embedding(model, text)


def load_ai_config(config_path: str) -> AIClient:
    """
    Load AI config from JSON file and return initialized AIClient.
    
    Args:
        config_path: Path to azure_openai_config.json (or GitHub Models variant).
    
    Returns:
        AIClient instance ready to use.
    """
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    return AIClient(config)
