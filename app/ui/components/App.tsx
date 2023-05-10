import React, { useState } from 'react';

export function App() {
  const [submitting, setSubmitting] = useState(false);
  const [textboxValue, setTextboxValue] = useState('');
  const [, setServerError] = useState('');

  function submitQuestion(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();

    if (!textboxValue) return;

    setSubmitting(true);

    fetch('/api', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        question: textboxValue,
      }),
    })
      .then((res) => res.json())
      .then((res) => {
        console.log(res);
        setSubmitting(false);
      })
      .catch((err) => {
        setServerError('There was an error submitting your question');
        setSubmitting(false);
        console.error(err);
      });
  }

  return (
    <form onSubmit={submitQuestion} className='app-container'>
      <p>Ask a question about the book and AI will answer it:</p>

      <div className='input-container'>
        <input value={textboxValue} onChange={(e) => setTextboxValue(e.target.value)} />
      </div>

      <div className='actions-container'>
        <button type='submit' disabled={submitting}>
          Ask question
        </button>
        <button type='button' disabled={submitting}>
          I'm feeling lucky
        </button>
      </div>
    </form>
  );
}
