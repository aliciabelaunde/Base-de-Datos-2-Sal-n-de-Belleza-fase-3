const express = require('express');
const cors    = require('cors');
const path    = require('path');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json());

app.use(express.static(path.join(__dirname, 'public')));

const authRoutes = require('./src/routes/auth');
app.use('/api/auth', authRoutes);

const clienteRoutes = require('./src/routes/cliente');
app.use('/api/cliente', clienteRoutes);

const personalRoutes = require('./src/routes/personal');
app.use('/api/personal', personalRoutes);

const atencionRoutes = require('./src/routes/atencion');
app.use('/api/atencion', atencionRoutes);

const adminRoutes = require('./src/routes/admin');
app.use('/api/admin', adminRoutes);

const duenaRoutes = require('./src/routes/duena');
app.use('/api/duena', duenaRoutes);

const mongoRoutes = require('./src/routes/mongo');
app.use('/api/mongo', mongoRoutes);

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'coco-auth.html'));
});

const { connectMongo } = require('./src/mongodb');
connectMongo().catch(err => console.error('❌ MongoDB:', err.message));

const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🌸 COCO server corriendo en http://localhost:${PORT}`);
});
server.timeout = 60000;