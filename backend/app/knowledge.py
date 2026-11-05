import re
import unicodedata
import numpy as np
from .config import ROOT


def normalize(text):
    return ''.join(ch for ch in unicodedata.normalize('NFD', text.lower()) if unicodedata.category(ch) != 'Mn')


def tokens(text):
    stop = {'le', 'la', 'les', 'un', 'une', 'des', 'de', 'du', 'en', 'et', 'est', 'que',
            'qu', 'ce', 'qui', 'pour', 'dans', 'au', 'aux', 'sur', 'je', 'tu', 'il', 'elle',
            'explique', 'definis', 'comment', 'pourquoi', 'moi', 'quel', 'quelle', 'sont'}
    return [t for t in re.findall(r'[a-z]{2,}', normalize(text)) if t not in stop]


class Corpus:
    def __init__(self):
        self.passages = []
        for file in sorted((ROOT / 'knowledge').glob('*.md')):
            blocks = file.read_text(encoding='utf-8').split('\n\n')
            for i, block in enumerate(blocks[1:]):
                if block.strip():
                    self.passages.append({'title': blocks[0].lstrip('# '), 'file': file.name,
                                          'id': f'{file.stem}:{i+1}', 'text': block.strip()})
        self.vocabulary = sorted(set(t for p in self.passages for t in tokens(p['text'])))
        self.index = {t: i for i, t in enumerate(self.vocabulary)}
        counts = np.array([self.vector(p['text']) for p in self.passages])
        self.idf = np.log((1+len(counts))/(1+(counts > 0).sum(axis=0)))+1
        self.matrix = counts * self.idf

    def vector(self, text):
        result = np.zeros(len(self.vocabulary))
        for t in tokens(text):
            if t in self.index:
                result[self.index[t]] += 1
        return result

    def search(self, question, limit=3):
        query = self.vector(question) * self.idf
        scores = self.matrix @ query / (np.linalg.norm(self.matrix, axis=1)*np.linalg.norm(query)+1e-12)
        query_tokens = set(tokens(question))
        return [self.passages[int(i)] for i in np.argsort(-scores, kind='stable')[:limit]
                if scores[i] >= 0.18 and query_tokens
                and len(query_tokens & set(tokens(self.passages[int(i)]['text']))) / len(query_tokens) >= 0.5]
