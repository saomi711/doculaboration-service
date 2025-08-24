import React, { useState, useEffect } from 'react';

const ConnectionTest: React.FC = () => {
  const [connectionStatus, setConnectionStatus] = useState<'testing' | 'connected' | 'failed'>('testing');
  const [apiUrl, setApiUrl] = useState('');

  useEffect(() => {
    const testConnection = async () => {
      const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:7000';
      setApiUrl(API_BASE_URL);
      
      try {
        const response = await fetch(`${API_BASE_URL}/health`);
        if (response.ok) {
          setConnectionStatus('connected');
        } else {
          setConnectionStatus('failed');
        }
      } catch (error) {
        console.error('Connection test failed:', error);
        setConnectionStatus('failed');
      }
    };

    testConnection();
  }, []);

  return (
    <div className="mb-4 p-3 rounded-lg border">
      <div className="flex items-center space-x-2">
        <span className="text-sm font-medium">API Connection:</span>
        <span className="text-xs text-gray-500">{apiUrl}</span>
        {connectionStatus === 'testing' && (
          <span className="text-yellow-600">Testing...</span>
        )}
        {connectionStatus === 'connected' && (
          <span className="text-green-600">✓ Connected</span>
        )}
        {connectionStatus === 'failed' && (
          <span className="text-red-600">✗ Failed</span>
        )}
      </div>
    </div>
  );
};

export default ConnectionTest;