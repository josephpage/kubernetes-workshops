import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

type Atelier = {
  title: string;
  description: string;
  href: string;
};

const ATELIERS: Atelier[] = [
  {
    title: 'Kratix',
    description:
      'Construire une Internal Developer Platform avec des Promises',
    href: '/docs/ateliers/kratix',
  },
  {
    title: 'Crossplane',
    description:
      'La même plateforme self-service avec XRD + Compositions',
    href: '/docs/ateliers/crossplane',
  },
  {
    title: 'Kubeception',
    description: 'Des clusters Kubernetes dans Kubernetes',
    href: '/docs/ateliers/kubeception',
  },
  {
    title: 'Kong',
    description: 'API Gateway et Ingress Controller sur Kubernetes',
    href: '/docs/ateliers/kong',
  },
];

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link className="button button--secondary button--lg" to="/docs/">
            Commencer
          </Link>
        </div>
      </div>
    </header>
  );
}

function AtelierCard({title, description, href}: Atelier) {
  return (
    <div className="col col--3">
      <Link to={href} className={clsx('card', styles.atelierCard)}>
        <div className="card__body">
          <Heading as="h3">{title}</Heading>
          <p>{description}</p>
        </div>
      </Link>
    </div>
  );
}

function HomepageAteliers() {
  return (
    <section className={styles.ateliersSection}>
      <div className="container">
        <Heading as="h2" className={styles.ateliersTitle}>
          Les ateliers
        </Heading>
        <div className="row">
          {ATELIERS.map((atelier) => (
            <AtelierCard key={atelier.title} {...atelier} />
          ))}
        </div>
      </div>
    </section>
  );
}

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description={siteConfig.tagline}>
      <HomepageHeader />
      <main>
        <HomepageAteliers />
      </main>
    </Layout>
  );
}
