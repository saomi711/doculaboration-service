import { TaskResponse, TaskStatus } from '../types';

const API_BASE_URL = process.env.REACT_APP_API_URL || '/api';

export class ApiService {
  static async startProcessing(gsheetName: string): Promise<TaskResponse> {
    console.log(`Starting processing for: ${gsheetName}`);
    console.log(`API URL: ${API_BASE_URL}/process/${encodeURIComponent(gsheetName)}`);
    
    const response = await fetch(`${API_BASE_URL}/process/${encodeURIComponent(gsheetName)}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
    });

    console.log(`Response status: ${response.status}`);
    console.log(`Response headers:`, response.headers);

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Error response:`, errorText);
      throw new Error(`Failed to start processing: ${response.statusText} - ${errorText}`);
    }

    return response.json();
  }

  static async getTaskStatus(taskId: string): Promise<TaskStatus> {
    const response = await fetch(`${API_BASE_URL}/status/${taskId}`);

    if (!response.ok) {
      throw new Error(`Failed to get task status: ${response.statusText}`);
    }

    return response.json();
  }

  static createEventSource(taskId: string): EventSource {
    return new EventSource(`${API_BASE_URL}/stream/${taskId}`);
  }

  static getDownloadUrls(gsheetName: string) {
    const encodedName = encodeURIComponent(gsheetName);
    return {
      pdf: `${API_BASE_URL}/pdf/${encodedName}/download`,
      odt: `${API_BASE_URL}/odt/${encodedName}/download`,
      docx: `${API_BASE_URL}/docx/${encodedName}/download`,
      json: `${API_BASE_URL}/json/${encodedName}/download`,
    };
  }

  static async downloadFile(url: string, filename: string): Promise<void> {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`Failed to download file: ${response.statusText}`);
      }

      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      
      window.URL.revokeObjectURL(downloadUrl);
    } catch (error) {
      console.error('Download failed:', error);
      throw error;
    }
  }
}