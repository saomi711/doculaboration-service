export interface ProcessingStatus {
  isProcessing: boolean;
  progress: number;
  message: string;
  stage: string;
  taskId?: string;
}

export interface ProcessedDocument {
  id: string;
  name: string;
  downloadUrls: {
    pdf: string;
    odt: string;
    docx: string;
    json: string;
  };
  createdAt: string;
  formats: string[];
}

export interface TaskStatus {
  status: 'PENDING' | 'STARTED' | 'SUCCESS' | 'FAILURE';
  result?: string;
  error?: string;
}

export interface TaskResponse {
  task_id: string;
  message?: string;
}