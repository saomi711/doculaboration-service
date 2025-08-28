import React, { useState, useEffect, useRef } from 'react';
import { ProcessingStatus, ProcessedDocument } from '../types';
import { ApiService } from '../services/api';
import ConnectionTest from './ConnectionTest';

const DocumentProcessor: React.FC = () => {
  const [documentName, setDocumentName] = useState('');
  const [status, setStatus] = useState<ProcessingStatus>({
    isProcessing: false,
    progress: 0,
    message: '',
    stage: ''
  });
  const [processedDocument, setProcessedDocument] = useState<ProcessedDocument | null>(null);
  const [error, setError] = useState<string>('');
  const [streamingLogs, setStreamingLogs] = useState<string[]>([]);
  const eventSourceRef = useRef<EventSource | null>(null);
  const statusPollingRef = useRef<NodeJS.Timeout | null>(null);

  const handleProcess = async () => {
    if (!documentName.trim()) {
      setError('Please enter a document name');
      return;
    }

    setError('');
    setStreamingLogs([]);
    setProcessedDocument(null);
    setStatus({
      isProcessing: true,
      progress: 0,
      message: 'Starting document processing...',
      stage: 'Initializing'
    });

    try {
      // Start the processing task
      const taskResponse = await ApiService.startProcessing(documentName);

      if (taskResponse.message && taskResponse.message.includes('already running')) {
        setStatus(prev => ({
          ...prev,
          message: 'Document is already being processed',
          stage: 'In Progress',
          taskId: taskResponse.task_id
        }));
      } else {
        setStatus(prev => ({
          ...prev,
          message: 'Processing task created',
          stage: 'Started',
          taskId: taskResponse.task_id
        }));
      }

      // Start streaming logs
      startStreaming(taskResponse.task_id);

      // Start polling for status
      startStatusPolling(taskResponse.task_id);

    } catch (err) {
      console.error('Processing error:', err);
      setError(err instanceof Error ? err.message : 'Failed to start processing');
      setStatus(prev => ({
        ...prev,
        isProcessing: false,
        message: 'Processing failed to start',
        stage: 'Error'
      }));
    }
  };

  const startStreaming = (taskId: string) => {
    // Close existing connection
    if (eventSourceRef.current) {
      eventSourceRef.current.close();
    }

    const eventSource = ApiService.createEventSource(taskId);
    eventSourceRef.current = eventSource;

    eventSource.onmessage = (event) => {
      const logLine = event.data;
      setStreamingLogs(prev => [...prev, logLine]);

      // Update progress based on log content
      updateProgressFromLog(logLine);
    };

    eventSource.onerror = (error) => {
      console.error('EventSource error:', error);
      eventSource.close();
    };
  };

  const updateProgressFromLog = (logLine: string) => {
    const line = logLine.toLowerCase();

    if (line.includes('step 1') || line.includes('json from google sheet')) {
      setStatus(prev => ({ ...prev, progress: 25, stage: 'Generating JSON', message: logLine }));
    } else if (line.includes('step 2') || line.includes('generating odt')) {
      setStatus(prev => ({ ...prev, progress: 50, stage: 'Generating ODT', message: logLine }));
    } else if (line.includes('step 3') || line.includes('generating docx')) {
      setStatus(prev => ({ ...prev, progress: 75, stage: 'Generating DOCX', message: logLine }));
    } else if (line.includes('step 4') || line.includes('generating pdf')) {
      setStatus(prev => ({ ...prev, progress: 90, stage: 'Generating PDF', message: logLine }));
    } else if (line.includes('completed successfully') || line.includes('✓')) {
      setStatus(prev => ({ ...prev, progress: 100, stage: 'Completed', message: logLine }));
    } else if (line.includes('fetching') || line.includes('downloading')) {
      setStatus(prev => ({ ...prev, progress: 10, stage: 'Fetching data', message: logLine }));
    }
  };

  const startStatusPolling = (taskId: string) => {
    const pollStatus = async () => {
      try {
        const taskStatus = await ApiService.getTaskStatus(taskId);

        if (taskStatus.status === 'SUCCESS') {
          // Task completed successfully
          setStatus(prev => ({
            ...prev,
            isProcessing: false,
            progress: 100,
            message: 'Document processed successfully!',
            stage: 'Completed'
          }));

          const processedDoc: ProcessedDocument = {
            id: taskId,
            name: documentName,
            downloadUrls: ApiService.getDownloadUrls(documentName),
            createdAt: new Date().toISOString(),
            formats: ['pdf', 'odt', 'docx', 'json']
          };

          setProcessedDocument(processedDoc);

          // Clean up
          if (eventSourceRef.current) {
            eventSourceRef.current.close();
          }
          if (statusPollingRef.current) {
            clearInterval(statusPollingRef.current);
          }

        } else if (taskStatus.status === 'FAILURE') {
          // Task failed
          setError(taskStatus.error || 'Processing failed');
          setStatus(prev => ({
            ...prev,
            isProcessing: false,
            message: 'Processing failed',
            stage: 'Error'
          }));

          // Clean up
          if (eventSourceRef.current) {
            eventSourceRef.current.close();
          }
          if (statusPollingRef.current) {
            clearInterval(statusPollingRef.current);
          }
        }
        // For PENDING and STARTED, continue polling

      } catch (err) {
        console.error('Status polling error:', err);
      }
    };

    // Poll every 2 seconds
    statusPollingRef.current = setInterval(pollStatus, 2000);

    // Initial poll
    pollStatus();
  };

  const handleDownload = async (format: 'pdf' | 'odt' | 'docx' | 'json') => {
    if (!processedDocument) return;

    try {
      const url = processedDocument.downloadUrls[format];
      const filename = `${processedDocument.name}.${format}`;
      await ApiService.downloadFile(url, filename);
    } catch (err) {
      setError(`Failed to download ${format.toUpperCase()} file`);
    }
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
      }
      if (statusPollingRef.current) {
        clearInterval(statusPollingRef.current);
      }
    };
  }, []);

  const resetProcess = () => {
    // Clean up any ongoing processes
    if (eventSourceRef.current) {
      eventSourceRef.current.close();
    }
    if (statusPollingRef.current) {
      clearInterval(statusPollingRef.current);
    }

    setDocumentName('');
    setStatus({
      isProcessing: false,
      progress: 0,
      message: '',
      stage: ''
    });
    setProcessedDocument(null);
    setError('');
    setStreamingLogs([]);
  };

  return (
    <div className="max-w-4xl mx-auto p-4 sm:p-6 bg-white rounded-lg shadow-lg">
      <h1 className="text-2xl sm:text-3xl font-bold text-gray-800 mb-6 sm:mb-8 text-center">
        Document Processor
      </h1>

      {/* Connection Test */}
      <ConnectionTest />

      {/* Usage Instructions Card */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 sm:p-6 mb-6">
        <h3 className="text-base sm:text-lg font-semibold text-blue-800 mb-4 flex items-center">
          <svg className="w-4 h-4 sm:w-5 sm:h-5 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
          </svg>
          How to Use This Service
        </h3>
        <div className="space-y-4">
          <div className="flex items-start space-x-3">
            <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-sm font-medium">
              1
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-blue-800 font-medium text-sm sm:text-base">Share your Google Sheet with the service</p>
              <div className="mt-2 bg-white border border-blue-200 rounded-md p-3">
                <p className="text-xs sm:text-sm text-gray-600 mb-2">Service Email:</p>
                <div className="flex flex-col sm:flex-row sm:items-center space-y-2 sm:space-y-0 sm:space-x-2">
                  <code className="bg-gray-100 px-2 py-1 rounded text-xs sm:text-sm font-mono text-gray-800 break-all sm:flex-1">
                    spectrum-895@spectrum-221613.iam.gserviceaccount.com
                  </code>
                  <button
                    onClick={() => {
                      navigator.clipboard.writeText('spectrum-895@spectrum-221613.iam.gserviceaccount.com');
                    }}
                    className="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded text-xs sm:text-sm transition duration-200 flex-shrink-0"
                    title="Copy email to clipboard"
                  >
                    Copy
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div className="flex items-start space-x-3">
            <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-sm font-medium">
              2
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-blue-800 font-medium text-sm sm:text-base">Copy the document name from your Google Sheet URL</p>
              <p className="text-xs sm:text-sm text-blue-600 mt-1">The document name is the name of your Google Sheet (not the URL).</p>
            </div>
          </div>

          <div className="flex items-start space-x-3">
            <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-sm font-medium">
              3
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-blue-800 font-medium text-sm sm:text-base">Paste the document name below and click "Process Document"</p>
              <p className="text-xs sm:text-sm text-blue-600 mt-1">The system will generate PDF, DOCX, ODT, and JSON formats</p>
            </div>
          </div>
        </div>
      </div>

      {/* Input Section */}
      <div className="mb-6">
        <label htmlFor="documentName" className="block text-sm font-medium text-gray-700 mb-2">
          Google Sheet Name
        </label>
        <input
          type="text"
          id="documentName"
          value={documentName}
          onChange={(e) => setDocumentName(e.target.value)}
          disabled={status.isProcessing}
          className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-gray-100 disabled:cursor-not-allowed"
          placeholder="Enter Google Sheet name..."
        />
        {error && (
          <p className="mt-2 text-sm text-red-600">{error}</p>
        )}
      </div>

      {/* Action Button */}
      <div className="mb-6">
        {!status.isProcessing && !processedDocument && (
          <button
            onClick={handleProcess}
            className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 px-4 rounded-md transition duration-200 ease-in-out transform hover:scale-105"
          >
            Process Document
          </button>
        )}

        {processedDocument && (
          <div className="space-y-3">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
              <button
                onClick={() => handleDownload('pdf')}
                className="bg-red-600 hover:bg-red-700 text-white font-medium py-3 px-4 rounded-md transition duration-200 ease-in-out transform hover:scale-105"
              >
                Download PDF
              </button>
              <button
                onClick={() => handleDownload('docx')}
                className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 px-4 rounded-md transition duration-200 ease-in-out transform hover:scale-105"
              >
                Download DOCX
              </button>
              <button
                onClick={() => handleDownload('odt')}
                className="bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-3 px-4 rounded-md transition duration-200 ease-in-out transform hover:scale-105"
              >
                Download ODT
              </button>
              <button
                onClick={() => handleDownload('json')}
                className="bg-green-600 hover:bg-green-700 text-white font-medium py-3 px-4 rounded-md transition duration-200 ease-in-out transform hover:scale-105"
              >
                Download JSON
              </button>
            </div>
            <button
              onClick={resetProcess}
              className="w-full bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-4 rounded-md transition duration-200 ease-in-out"
            >
              Process Another Document
            </button>
          </div>
        )}
      </div>

      {/* Processing Status Window */}
      {(status.isProcessing || status.message) && (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-6">
          <h3 className="text-base sm:text-lg font-semibold text-gray-800 mb-3">Processing Status</h3>

          {status.isProcessing && (
            <div className="mb-4">
              <div className="flex justify-between text-xs sm:text-sm text-gray-600 mb-1">
                <span>Progress</span>
                <span>{status.progress}%</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div
                  className="bg-blue-600 h-2 rounded-full transition-all duration-300 ease-out"
                  style={{ width: `${status.progress}%` }}
                ></div>
              </div>
            </div>
          )}

          <div className="space-y-2 mb-4">
            <div className="flex flex-col sm:flex-row sm:items-center">
              <span className="text-xs sm:text-sm font-medium text-gray-700 sm:mr-2">Stage:</span>
              <span className="text-xs sm:text-sm text-gray-600">{status.stage}</span>
            </div>
            <div className="flex flex-col sm:flex-row sm:items-center">
              <span className="text-xs sm:text-sm font-medium text-gray-700 sm:mr-2">Status:</span>
              <div className="flex items-center">
                <span className="text-xs sm:text-sm text-gray-600 break-words">{status.message}</span>
                {status.isProcessing && (
                  <div className="ml-2 animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600 flex-shrink-0"></div>
                )}
              </div>
            </div>
            {status.taskId && (
              <div className="flex flex-col sm:flex-row sm:items-center">
                <span className="text-xs sm:text-sm font-medium text-gray-700 sm:mr-2">Task ID:</span>
                <span className="text-xs text-gray-500 font-mono break-all">{status.taskId}</span>
              </div>
            )}
          </div>

          {/* Streaming Logs */}
          {streamingLogs.length > 0 && (
            <div className="bg-black text-green-400 p-2 sm:p-3 rounded-md font-mono text-xs max-h-32 sm:max-h-40 overflow-y-auto">
              <div className="text-gray-400 mb-2">Live Output:</div>
              {streamingLogs.slice(-20).map((log, index) => (
                <div key={index} className="whitespace-pre-wrap break-words">
                  {log}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Processed Document Info */}
      {processedDocument && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4">
          <h3 className="text-base sm:text-lg font-semibold text-green-800 mb-3">Document Ready</h3>
          <div className="space-y-2 text-xs sm:text-sm">
            <div className="flex flex-col sm:flex-row sm:justify-between">
              <span className="font-medium text-green-700">Name:</span>
              <span className="text-green-600 break-words">{processedDocument.name}</span>
            </div>
            <div className="flex flex-col sm:flex-row sm:justify-between">
              <span className="font-medium text-green-700">Formats:</span>
              <span className="text-green-600 uppercase">{processedDocument.formats.join(', ')}</span>
            </div>
            <div className="flex flex-col sm:flex-row sm:justify-between">
              <span className="font-medium text-green-700">Created:</span>
              <span className="text-green-600 break-words">
                {new Date(processedDocument.createdAt).toLocaleString()}
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default DocumentProcessor;